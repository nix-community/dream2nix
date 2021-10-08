import json
import os
import re
import subprocess as sp
import sys
import tempfile
from cleo import Application, Command
from cleo.helpers import option

import networkx as nx

dream2nix_src = os.environ.get("dream2nixSrc")



class PackageCommand(Command):

  description = (
    "Package a software project using nix"
  )

  name = "package"

  options = [
    option(
      "source",
      None,
      "source of the package, can be a path or flake-like spec",
      flag=False,
      multiple=False
    ),
    option("translator", None, "which translator to use", flag=False),
    option("output", None, "output file/directory for the dream.lock", flag=False),
    option(
      "combined",
      None,
      "store only one hash for all sources combined"
      " (smaller lock file but larger FOD)",
      flag=False
    ),
    option(
      "extra-arg",
      None,
      "extra arguments for selected translator",
      flag=False,
      multiple=True
    ),
    option("force", None, "override existing files", flag=True),
  ]

  def handle(self):
    if self.io.is_interactive():
      self.line(f"\n{self.description}\n")

    # parse extra args
    specified_extra_args = {
      arg[0]: arg[1] for arg in map(
        lambda e: e.split('='),
        self.option("extra-arg"),
      )
    }

    # ensure output directory
    output = self.option("output")
    if not output:
      output = './.'
    if not os.path.isdir(output):
      os.mkdir(output)
    filesToCreate = ('default.nix', 'dream.lock')
    if self.option('force'):
      for f in filesToCreate:
        if os.path.isfile(f):
          os.remove(f)
    else:
      existingFiles = set(os.listdir(output))
      if any(f in existingFiles for f in filesToCreate):
        print(
          f"output directory {output} already contains a 'default.nix' "
          "or 'dream.lock'. Delete first, or user '--force'.",
          file=sys.stderr,
        )
        exit(1)
    output = os.path.realpath(output)
    outputDreamLock = f"{output}/dream.lock"
    outputDefaultNix = f"{output}/default.nix"

    # verify source
    source = self.option("source")
    if not source:
      source = os.path.realpath('./.')
      print(
        f"Source not specified. Defaulting to current directory: {source}",
        file=sys.stderr,
      )
    # check if source is valid fetcher spec
    sourceSpec = {}
    if source.partition(':')[0] in os.environ.get("fetcherNames", None).split():
      print(f"fetching source for '{source}'")
      sourceSpec =\
        callNixFunction("fetchers.translateShortcut", shortcut=source)
      source =\
        buildNixFunction("fetchers.fetchShortcut", shortcut=source)
    else:
      # check if source path exists
      if not os.path.exists(source):
        print(f"Input source '{source}' does not exist", file=sys.stdout)
        exit(1)
      source = os.path.realpath(source)

    # select translator
    translatorsSorted = sorted(
      list_translators_for_source(source),
      key=lambda t: (
        not t['compatible'],
        ['pure', 'ifd', 'impure'].index(t['type'])
      )
    )
    translator = self.option("translator")
    if not translator:
      chosen = self.choice(
        'Select translator',
        list(map(
          lambda t: f"{t['subsystem']}.{t['type']}.{t['name']}{'  (compatible)' if t['compatible'] else ''}",
          translatorsSorted
        )),
        0
      )
      translator = chosen
      translator = list(filter(
        lambda t: [t['subsystem'], t['type'], t['name']] == translator.split('  (')[0].split('.'),
        translatorsSorted,
      ))[0]
    else:
      translator = translator.split('.')
      if len(translator) == 3:
        translator = list(filter(
          lambda t: [t['subsystem'], t['type'], t['name']] == translator,
          translatorsSorted,
        ))[0]
      elif len(translator) == 1:
        translator = list(filter(
          lambda t:  [t['name']] == translator,
          translatorsSorted,
        ))[0]

    # raise error if any specified extra arg is unknown
    unknown_extra_args = set(specified_extra_args.keys()) - set(translator['specialArgs'].keys())
    if unknown_extra_args:
      print(
        f"Invalid extra args for translator '{translator['name']}': "
        f" {', '.join(unknown_extra_args)}"
        "\nPlease remove these parameters",
        file=sys.stderr
      )
      exit(1)

    # transform flags to bool
    for argName, argVal in specified_extra_args.copy().items():
      if translator['specialArgs'][argName]['type'] == 'flag':
        if argVal.lower() in ('yes', 'y', 'true'):
          specified_extra_args[argName] = True
        elif argVal.lower() in ('no', 'n', 'false'):
          specified_extra_args[argName] = False
        else:
          print(
            f"Invalid value {argVal} for argument {argName}",
            file=sys.stderr
          )
      
    specified_extra_args =\
      {k: (bool(v) if translator['specialArgs'][k]['type'] == 'flag' else v ) \
          for k, v in specified_extra_args.items()}

    # on non-interactive session, assume defaults for unspecified extra args
    if not self.io.is_interactive():
      specified_extra_args.update(
        {n: (True if v['type'] == 'flag' else v['default']) \
          for n, v in translator['specialArgs'].items() \
          if n not in specified_extra_args and 'default' in v}
      )
    unspecified_extra_args = \
      {n: v for n, v in translator['specialArgs'].items() \
        if n not in specified_extra_args}
    # raise error if any extra arg unspecified in non-interactive session
    if unspecified_extra_args:
      if not self.io.is_interactive():
        print(
          f"Please specify the following extra arguments required by translator '{translator['name']}' :\n" \
            ', '.join(unspecified_extra_args.keys()),
          file=sys.stderr
        )
        exit(1)
      # interactively retrieve unswers for unspecified extra arguments
      else:
        print(f"\nThe translator '{translator['name']}' requires additional options")
        for arg_name, arg in unspecified_extra_args.items():
          print('')
          if arg['type'] == 'flag':
            print(f"Please specify '{arg_name}': {arg['description']}")
            specified_extra_args[arg_name] = self.confirm(f"{arg['description']}:", False)
          else:
            print(f"Please specify '{arg_name}': {arg['description']}")
            print(f"Example values: " + ', '.join(arg['examples']))
            specified_extra_args[arg_name] = self.ask(f"{arg_name}:", arg.get('default'))
    
    # arguments for calling the translator nix module
    translator_input = dict(
      inputFiles=[],
      inputDirectories=[source],
      outputFile=outputDreamLock,
    )
    translator_input.update(specified_extra_args)

    # build the translator bin
    t = translator
    translator_path = buildNixAttribute(
      f"translators.translators.{t['subsystem']}.{t['type']}.{t['name']}.translateBin"
    )
    
    # dump translator arguments to json file and execute translator
    print("Translating upstream metadata")
    with tempfile.NamedTemporaryFile("w") as input_json_file:
      json.dump(translator_input, input_json_file, indent=2)
      input_json_file.seek(0) # flushes write cache

      # execute translator
      sp.run(
        [f"{translator_path}/bin/translate", input_json_file.name]
      )
    
    # raise error if output wasn't produced
    if not os.path.isfile(outputDreamLock):
      raise Exception(f"Translator failed to create dream.lock")

    # read produced lock file
    with open(outputDreamLock) as f:
      lock = json.load(f)
    
    # write translator information to lock file
    lock['generic']['translatedBy'] = f"{t['subsystem']}.{t['type']}.{t['name']}"
    lock['generic']['translatorParams'] = " ".join(sys.argv[2:])

    # add main package source
    mainPackage = lock['generic']['mainPackage']
    if mainPackage:
      mainSource = sourceSpec.copy()
      if not mainSource:
        mainSource = dict(
          type="unknown",
          version="unknown",
        )
      else:
        for field in ('versionField',):
          if field in mainSource:
            del mainSource[field]
        mainSource['version'] = sourceSpec[sourceSpec['versionField']]
      lock['sources'][mainPackage] = mainSource

    # clean up dependency graph
    # remove empty entries
    depGraph = lock['generic']['dependencyGraph']
    if 'dependencyGraph' in lock['generic']:
      for pname, deps in depGraph.copy().items():
        if not deps:
          del depGraph[pname]

    # remove cyclic dependencies
    edges = set()
    for pname, deps in depGraph.items():
      for dep in deps:
        edges.add((pname, dep))
    G = nx.DiGraph(sorted(list(edges)))
    cycle_count = 0
    removed_edges = []
    for pname in list(depGraph.keys()):
      try:
        while True:
          cycle = nx.find_cycle(G, pname)
          cycle_count += 1
          # remove_dependecy(indexed_pkgs, G, cycle[-1][0], cycle[-1][1])
          node_from, node_to = cycle[-1][0], cycle[-1][1]
          G.remove_edge(node_from, node_to)
          depGraph[node_from].remove(node_to)
          removed_edges.append((node_from, node_to))
      except nx.NetworkXNoCycle:
        continue
    if removed_edges:
      removed_cycles_text = 'Removed Cyclic dependencies:'
      for node, removed_node in removed_edges:
        removed_cycles_text += f"\n  {node} -> {removed_node}"
      print(removed_cycles_text)
    lock['generic']['dependencyCyclesRemoved'] = True

    # calculate combined hash if --combined was specified
    if self.option('combined'):

      print("Building FOD of combined sources to retrieve output hash")

      # remove hashes from lock file and init sourcesCombinedHash with emtpy string
      strip_hashes_from_lock(lock)
      lock['generic']['sourcesCombinedHash'] = ""
      with open(outputDreamLock, 'w') as f:
        json.dump(lock, f, indent=2)

      # compute FOD hash of combined sources
      proc = sp.run(
        [
          "nix", "build", "--impure", "-L", "--expr",
          f"(import {dream2nix_src} {{}}).fetchSources {{ dreamLock = {outputDreamLock}; }}"
        ],
        capture_output=True,
      )

      # read the output hash from the failed build log
      match = re.search(r"FOD_PATH=(.*=)", proc.stderr.decode())
      if not match:
        print(proc.stderr.decode())
        print(proc.stdout.decode())
        raise Exception("Could not find FOD hash in FOD log")
      hash = match.groups()[0]
      print(f"Computed FOD hash: {hash}")

      # store the hash in the lock
      lock['generic']['sourcesCombinedHash'] = hash
    
    # re-write dream.lock
    with open(outputDreamLock, 'w') as f:
      json.dump(order_dict(lock), f, indent=2)

    # create default.nix
    template = callNixFunction(
      'apps.apps.cli.templateDefaultNix',
      dream2nixLocationRelative=os.path.relpath(dream2nix_src, output),
      dreamLock = lock,
      sourcePathRelative = os.path.relpath(source, os.path.dirname(outputDefaultNix))
    )
    # with open(f"{dream2nix_src}/apps/cli2/templateDefault.nix") as template:
    with open(outputDefaultNix, 'w') as defaultNix:
      defaultNix.write(template)

    print(f"Created {output}/{{dream.lock,default.nix}}")



def callNixFunction(function_path, **kwargs):
  with tempfile.NamedTemporaryFile("w") as input_json_file:
    json.dump(dict(**kwargs), input_json_file, indent=2)
    input_json_file.seek(0) # flushes write cache
    env = os.environ.copy()
    env.update(dict(
      FUNC_ARGS=input_json_file.name
    ))
    proc = sp.run(
      [
        "nix", "eval", "--impure", "--raw", "--expr",
        f'''
          let
            d2n = (import {dream2nix_src} {{}});
          in
            builtins.toJSON (
              (d2n.utils.makeCallableViaEnv d2n.{function_path}) {{}}
            )
        ''',
      ],
      capture_output=True,
      env=env
    )
  if proc.returncode:
    print(f"Failed calling nix function '{function_path}'", file=sys.stderr)
    print(proc.stderr.decode(), file=sys.stderr)
    exit(1)

  # parse result data
  return json.loads(proc.stdout)


def buildNixFunction(function_path, **kwargs):
  with tempfile.NamedTemporaryFile("w") as input_json_file:
    json.dump(dict(**kwargs), input_json_file, indent=2)
    input_json_file.seek(0) # flushes write cache
    env = os.environ.copy()
    env.update(dict(
      FUNC_ARGS=input_json_file.name
    ))
    proc = sp.run(
      [
        "nix", "build", "--impure", "-o", "tmp-result", "--expr",
        f'''
          let
            d2n = (import {dream2nix_src} {{}});
          in
            (d2n.utils.makeCallableViaEnv d2n.{function_path}) {{}}
        ''',
      ],
      capture_output=True,
      env=env
    )
  if proc.returncode:
    print(f"Failed calling nix function '{function_path}'", file=sys.stderr)
    print(proc.stderr.decode(), file=sys.stderr)
    exit(1)

  # return store path of result
  result = os.path.realpath("tmp-result")
  os.remove("tmp-result")
  return result


def buildNixAttribute(attribute_path):
  proc = sp.run(
    [
      "nix", "build", "--impure", "-o", "tmp-result", "--expr",
      f"(import {dream2nix_src} {{}}).{attribute_path}",
    ],
    capture_output=True,
  )
  if proc.returncode:
    print(f"Failed to build '{attribute_path}'", file=sys.stderr)
    print(proc.stderr.decode(), file=sys.stderr)
    exit(1)

  result = os.path.realpath("tmp-result")
  os.remove("tmp-result")
  return result


def list_translators_for_source(sourcePath):
  translatorsList = callNixFunction(
    "translators.translatorsForInput",
    inputDirectories=[sourcePath],
    inputFiles=[],
  )
  return list(sorted(translatorsList, key=lambda t: t['compatible']))


def order_dict(d):
  return {k: order_dict(v) if isinstance(v, dict) else v
    for k, v in sorted(d.items())}


application = Application("package")
application.add(PackageCommand())

if __name__ == '__main__':
  application.run()
