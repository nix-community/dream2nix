import json
import os
import re
import subprocess as sp
import sys
import tempfile
from cleo import Application, Command
from cleo.helpers import option

import networkx as nx

dream2nix_src = "./src"



class PackageCommand(Command):

  description = (
    "Package a software project using nix"
  )

  name = "package"

  options = [
    option(
      "source",
      None,
      "source of the package",
      flag=False,
      multiple=True
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

    # verify source
    source = self.option("source")
    if not source:
      source = os.path.realpath('./.')
      print(
        f"Source not specified. Defaulting to current directory: {source}",
        file=sys.stderr,
      )
    # check if source path exists
    if not os.path.exists(source):
      raise print(f"Input path '{path}' does not exist", file=sys.stdout)
      exit(1)

    # determine output file
    output = self.option("output")
    if not output:
      output = './dream.lock'
    if os.path.isdir(output):
      output = f"{output}/dream.lock"
    output = os.path.realpath(output)

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
          lambda t: f"{t['subsystem']}.{t['type']}.{t['name']}",
          translatorsSorted
        )),
        0
      )
      translator = chosen
    translator = list(filter(
      lambda t: [t['subsystem'], t['type'], t['name']] == translator.split('.'),
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
      outputFile=output,
    )
    translator_input.update(specified_extra_args)


    # remove output file if exists
    if os.path.exists(output):
      os.remove(output)

    # build the translator bin
    t = translator
    translator_path = buildNixDerivation(
      f"translators.translators.{t['subsystem']}.{t['type']}.{t['name']}.translateBin"
    )
    
    # dump translator arguments to json file and execute translator
    with tempfile.NamedTemporaryFile("w") as input_json_file:
      json.dump(translator_input, input_json_file, indent=2)
      input_json_file.seek(0) # flushes write cache

      # execute translator
      sp.run(
        [f"{translator_path}/bin/translate", input_json_file.name]
      )
    
    # raise error if output wasn't produced
    if not os.path.isfile(output):
      raise Exception(f"Translator failed to create dream.lock")

    # read produced lock file
    with open(output) as f:
      lock = json.load(f)
    
    # write translator information to lock file
    lock['generic']['translatedBy'] = f"{subsystem}.{trans_type}.{trans_name}"
    lock['generic']['translatorParams'] = " ".join(sys.argv[2:])

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
    if args.combined:

      print("Building FOD of combined sources to retrieve output hash")

      # remove hashes from lock file and init sourcesCombinedHash with emtpy string
      strip_hashes_from_lock(lock)
      lock['generic']['sourcesCombinedHash'] = ""
      with open(output, 'w') as f:
        json.dump(lock, f, indent=2)

      # compute FOD hash of combined sources
      proc = sp.run(
        [
          "nix", "build", "--impure", "-L", "--expr",
          f"(import {dream2nix_src} {{}}).fetchSources {{ dreamLock = {output}; }}"
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
    with open(output, 'w') as f:
      json.dump(order_dict(lock), f, indent=2)

    print(f"Created {output}")


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
          builtins.toJSON (
            (import {dream2nix_src} {{}}).{function_path} {{}}
          )
        ''',
      ],
      capture_output=True,
      env=env
    )
  if proc.returncode:
    print(f"Failed calling '{function_path}'", file=sys.stderr)
    print(proc.stderr.decode(), file=sys.stderr)
    exit(1)

  # parse data for auto selected translator
  return json.loads(proc.stdout)


def buildNixDerivation(attribute_path):
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


application = Application("package")
application.add(PackageCommand())

if __name__ == '__main__':
  application.run()
