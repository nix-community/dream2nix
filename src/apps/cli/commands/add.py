import json
import os
import pathlib
import re
import shutil
import subprocess as sp
import sys
import tempfile
from glob import glob

import networkx as nx
from cleo import Command, argument, option

from utils import config, dream2nix_src, checkLockJSON, list_translators_for_source, strip_hashes_from_lock
from nix_ffi import nix, callNixFunction, buildNixFunction, buildNixAttribute


class AddCommand(Command):

  description = (
    f"Add a package to {config['repoName']}"
  )

  name = "add"

  arguments = [
    argument(
      "source",
      "Sources of the packages. Can be a paths, tarball URLs, or flake-style specs",
      multiple=True
    )
  ]

  options = [
    option("translator", None, "which translator to use", flag=False),
    option("target", None, "target file/directory for the dream-lock.json", flag=False),
    option("attribute-name", None, "attribute name for new new pakcage", flag=False),
    option(
      "packages-root",
      None,
      "Put package under a new directory inside packages-root",
      flag=False
    ),
    option(
      "aggregate",
      None,
      "store only one aggregated hash for all sources"
      " (smaller lock file but larger FOD, worse caching)",
      flag=True
    ),
    option(
      "sub-dirs",
      None,
      "whether to scan sub-directories for sub-projects",
      flag=True
    ),
    option(
      "arg",
      None,
      "extra arguments for selected translator",
      flag=False,
      multiple=True
    ),
    option("force", None, "override existing files", flag=True),
    option("no-default-nix", None, "do not create default.nix", flag=True),
    option("invalidation-hash", None, "invalidation hash to attach", flag=False),
  ]

  def handle(self):
    sources = self.argument("source")

    # ensure packages-root
    package_root = self.find_package_root()

    # parse extra args
    specified_extra_args = self.parse_extra_args()

    # get source path and spec
    sourcePath, sourceSpec = self.parse_source(sources[0])

    # process main package
    print(f"\n\nProcessing main package: {sources[0]}")
    main_package_dir_name, existing_names = self.handle_one_recursive(
      [],
      package_root,
      sourcePath,
      sourceSpec,
      specified_extra_args,
      recursive=self.option('sub-dirs'),
    )

    # process subpackages
    for idx, source in enumerate(sources[1:]):
      print(f"\n\nProcessing subpackage {idx+1}: {source}")
      # get source path and spec
      sourcePath, sourceSpec = self.parse_source(source)
      attr_name = self.handle_one_recursive(
        existing_names,
        sub_package_root,
        sourcePath,
        sourceSpec,
        specified_extra_args,
        recursive=self.option('sub-dirs'),
      )
      existing_names.append(attr_name)


  # handle one source and scan subdirectories for more projects
  def handle_one_recursive(
      self,
      existing_names,
      package_root,
      sourcePath,
      sourceSpec,
      specified_extra_args,
      recursive=False,
  ):

    # list all translators for source and sub directories
    translators_dict = list_translators_for_source(sourcePath)
    for path, translators in translators_dict.copy().items():
      if all (t['compatible'] == False for t in translators):
        del translators_dict[path]

    # handle main source
    main_package_dir_name = self.handle_one(
      existing_names,
      package_root,
      sourcePath,
      sourceSpec,
      specified_extra_args,
      translators=translators_dict[sourcePath],
    )
    del translators_dict[sourcePath]

    existing_names += [main_package_dir_name]

    # clean sub-package outputs
    sub_package_root = f"{package_root}/{main_package_dir_name}"
    for subdir in glob(f"{sub_package_root}/*/"):
      shutil.rmtree(subdir)

    # handle each path without recursing further
    if recursive:
      print(json.dumps(translators_dict, indent=2))
      for sourcePathSub, translators in translators_dict.items():
        sourceSpecSub = sourceSpec.copy()
        if 'dir' in sourceSpecSub:
          sourceSpecSub['dir'] += os.path.relpath(sourcePathSub, sourcePath)
        else:
          sourceSpecSub['dir'] = os.path.relpath(sourcePathSub, sourcePath)

        print(f"\n\nProcessing package from sub-dir {sourceSpecSub['dir']}")

        package_root_sub = \
          f"{package_root}/{main_package_dir_name}/{sourceSpecSub['dir'].rpartition('/')[0]}"

        new_name = self.handle_one(
          existing_names,
          package_root_sub,
          sourcePathSub,
          sourceSpecSub,
          specified_extra_args,
          translators,
        )

        existing_names += [new_name]

    return main_package_dir_name, existing_names


  def handle_one(
      self,
      existing_names,
      package_root,
      sourcePath,
      sourceSpec,
      specified_extra_args,
      translators,
  ):

    lock, specified_extra_args, translator =\
      self.translate_from_source(specified_extra_args, sourcePath, translators)

    # get package name and version from lock
    defaultPackage = lock['_generic']['defaultPackage']
    defaultPackageVersion = lock['_generic']['packages'][defaultPackage]

    # calculate output directory and attribute name
    main_package_dir_name = self.define_attribute_name(
      defaultPackage,
      existing_names,
    )

    # calculate output files
    filesToCreate, output =\
      self.calc_outputs(main_package_dir_name, package_root)
    outputDreamLock = f"{output}/dream-lock.json"
    outputDefaultNix = f"{output}/default.nix"

    # add translator information to lock
    self.extend_with_translator_info(lock, specified_extra_args, translator)

    # add main package source
    self.add_main_source(lock, defaultPackage, defaultPackageVersion, sourceSpec)

    # add location
    if 'location' not in lock['_generic']:
      if 'dir' in sourceSpec:
        lock['_generic']['location'] = sourceSpec['dir']
      else:
        lock['_generic']['location'] = ''

    # clean up dependency graph
    if 'dependencies' in lock['_generic']:
      self.postprocess_dep_graph(lock)

    # calculate aggregated hash if --aggregate was specified
    if self.option('aggregate'):
      self.aggregate_hashes(lock, outputDreamLock)

    # validate dream lock format
    checkLockJSON(lock)

    # format dream lock
    lockStr = self.format_lock_str(lock)

    # save dream lock file
    with open(outputDreamLock, 'w') as f:
      f.write(lockStr)
    print(f"Created {output}/dream-lock.json")

    # create default.nix
    if 'default.nix' in filesToCreate:
      self.create_default_nix(lock, output, outputDefaultNix, sourcePath)

    # add new package to git
    if config['isRepo']:
      sp.run(["git", "add", "-N", output])

    return main_package_dir_name

  def translate_from_source(self, specified_extra_args, sourcePath, translators):
    # select translator
    translator = self.select_translator(translators)
    # raise error if any specified extra arg is un-known
    specified_extra_args = self.declare_extra_args(specified_extra_args, translator)
    # do the translation and produce dream lock
    lock = self.run_translate(sourcePath, specified_extra_args, translator)
    return lock, specified_extra_args, translator

  def parse_extra_args(self):
    specified_extra_args = {
      arg[0]: arg[1] for arg in map(
        lambda e: e.split('='),
        self.option("arg"),
      )
    }
    return specified_extra_args

  def create_default_nix(self, lock, output, outputDefaultNix, sourcePath):
    template = callNixFunction(
      'apps.apps.cli.templateDefaultNix',
      dream2nixLocationRelative=os.path.relpath(dream2nix_src, output),
      dreamLock=lock,
      sourcePathRelative=os.path.relpath(sourcePath, os.path.dirname(outputDefaultNix))
    )
    with open(outputDefaultNix, 'w') as defaultNix:
      defaultNix.write(template)
      print(f"Created {output}/default.nix")

  def find_package_root(self):
    if self.option("packages-root"):
      packages_root = self.option("packages-root")
    elif config['packagesDir']:
      packages_root = config['packagesDir']
    else:
      packages_root = './.'
    return packages_root

  def format_lock_str(self, lock):
    lockStr = json.dumps(lock, indent=2, sort_keys=True)
    lockStr = lockStr \
      .replace("[\n          ", "[ ") \
      .replace("\"\n        ]", "\" ]") \
      .replace(",\n          ", ", ")
    return lockStr

  def aggregate_hashes(self, lock, outputDreamLock):
    print("Building FOD of aggregates sources to retrieve output hash")
    # remove hashes from lock file and init sourcesAggregatedHash with empty string
    strip_hashes_from_lock(lock)
    lock['_generic']['sourcesAggregatedHash'] = ""
    with open(outputDreamLock, 'w') as f:
      json.dump(lock, f, indent=2)
    # compute FOD hash of aggregated sources
    proc = nix(
      "build", "--impure", "-L", "--show-trace", "--expr",
      f"(import {dream2nix_src} {{}}).fetchSources {{ dreamLock = {outputDreamLock}; }}"
    )
    # read the output hash from the failed build log
    match = re.search(r"FOD_HASH=(.*=)", proc.stderr.decode())
    if not match:
      print(proc.stderr.decode())
      print(proc.stdout.decode())
      print(
        "Error: Could not find FOD hash in FOD log",
        file=sys.stderr,
      )
    hash = match.groups()[0]
    print(f"Computed FOD hash: {hash}")
    # store the hash in the lock
    lock['_generic']['sourcesAggregatedHash'] = hash

  def postprocess_dep_graph(self, lock):
    depGraph = lock['_generic']['dependencies']
    # remove empty entries
    if 'dependencies' in lock['_generic']:
      for pname, deps in depGraph.copy().items():
        if not deps:
          del depGraph[pname]
    # mark cyclic dependencies
    edges = set()
    for pname, versions in depGraph.items():
      for version, deps in versions.items():
        for dep in deps:
          edges.add(((pname, version), tuple(dep)))
    G = nx.DiGraph(sorted(list(edges)))
    cycle_count = 0
    removed_edges = []
    for pname, versions in depGraph.items():
      for version in versions.keys():
        key = (pname, version)
        try:
          while True:
            cycle = nx.find_cycle(G, key)
            cycle_count += 1
            node_from, node_to = cycle[-1][0], cycle[-1][1]
            G.remove_edge(node_from, node_to)
            removed_edges.append((node_from, node_to))
        except nx.NetworkXNoCycle:
          continue
    lock['cyclicDependencies'] = {}
    if removed_edges:
      cycles_text = 'Detected Cyclic dependencies:'
      for node, removed in removed_edges:
        n_name, n_ver = node[0], node[1]
        r_name, r_ver = removed[0], removed[1]
        cycles_text += \
          f"\n  {n_name}#{n_ver} -> {r_name}#{r_ver}"
        if n_name not in lock['cyclicDependencies']:
          lock['cyclicDependencies'][n_name] = {}
        if n_ver not in lock['cyclicDependencies'][n_name]:
          lock['cyclicDependencies'][n_name][n_ver] = []
        lock['cyclicDependencies'][n_name][n_ver].append(removed)
      print(cycles_text)

  def add_main_source(self, lock, defaultPackage, defaultPackageVersion, sourceSpec):
    mainSource = sourceSpec.copy()
    if not mainSource:
      mainSource = dict(
        type="unknown",
      )
    else:
      for key in ['pname', 'version']:
        if key in mainSource:
          del mainSource[key]
    if defaultPackage not in lock['sources']:
      lock['sources'][defaultPackage] = {
        defaultPackageVersion: mainSource
      }
    else:
      lock['sources'][defaultPackage][defaultPackageVersion] = mainSource

  def extend_with_translator_info(self, lock, specified_extra_args, translator):
    t = translator
    lock['_generic']['translatorParams'] = " ".join(
      [
        '--translator',
        f"{translator['subsystem']}.{translator['type']}.{translator['name']}",
      ] + (
        ["--aggregate"] if self.option('aggregate') else []
      ) + [
        f"--arg {n}={v}" for n, v in specified_extra_args.items()
      ])
    lock['_generic']['invalidationHash'] = self.option('invalidation-hash')

  def calc_outputs(self, main_package_dir_name, packages_root):
    if self.option('target'):
      if self.option('target').startswith('/'):
        output = self.option('target')
      else:
        output = f"{packages_root}/{self.option('target')}"
    else:
      output = f"{packages_root}/{main_package_dir_name}"
    # collect files to create
    filesToCreate = ['dream-lock.json']
    # create output dir
    pathlib.Path(output).mkdir(parents=True, exist_ok=True)
    existingFiles = set(os.listdir(output))
    if not self.option('no-default-nix') \
        and not 'default.nix' in existingFiles \
        and not config['projectRoot']:
      filesToCreate.append('default.nix')
    # overwrite existing files only if --force is set
    if self.option('force'):
      for f in filesToCreate:
        if os.path.isfile(f):
          os.remove(f)
    # raise error if any file exists already
    else:
      if any(f in existingFiles for f in filesToCreate):
        print(
          f"output directory {output} already contains a 'default.nix' "
          "or 'dream-lock.json'. Resolve via one of these:\n"
          "  - use --force to overwrite files\n"
          "  - use --target to specify another target dir",
          file=sys.stderr,
        )
        exit(1)
    output = os.path.realpath(output)
    return filesToCreate, output

  def define_attribute_name(self, defaultPackage, existing_names):
    # only respect --attribute-name option for main package
    if not existing_names:
      attributeName = self.option('attribute-name')
      if attributeName:
        return attributeName

    attributeName = defaultPackage.strip('@').replace('/', '-')

    if attributeName in existing_names:
      attributeName = attributeName + '-subpackage'

    # verify / change main package dir name
    print(
      f"Current package attribute name is: {attributeName}"
      " (use --attribute-name to override)")
    return attributeName

  def run_translate(self, sourcePath, specified_extra_args, translator):
    # build the translator bin
    t = translator
    translator_path = buildNixAttribute(
      f"translators.translators.{t['subsystem']}.{t['type']}.{t['name']}.translateBin"
    )
    # direct outputs of translator to temporary file
    with tempfile.NamedTemporaryFile("r") as output_temp_file:
      # arguments for calling the translator nix module
      translator_input = dict(
        source=sourcePath,
        outputFile=output_temp_file.name,
      )
      translator_input.update(specified_extra_args)

      # dump translator arguments to json file and execute translator
      print("\nTranslating project metadata")
      with tempfile.NamedTemporaryFile("w") as input_json_file:
        json.dump(translator_input, input_json_file, indent=2)
        input_json_file.seek(0)  # flushes write cache

        # execute translator
        sp.run(
          [f"{translator_path}", input_json_file.name]
        )

      # raise error if output wasn't produced
      if not output_temp_file.read():
        raise Exception(f"Translator failed to create dream-lock.json")

      # read produced lock file
      with open(output_temp_file.name) as f:
        lock = json.load(f)
    return lock

  def declare_extra_args(self, specified_extra_args, translator):
    unknown_extra_args = set(specified_extra_args.keys()) - set(translator['extraArgs'].keys())
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
      if translator['extraArgs'][argName]['type'] == 'flag':
        if isinstance(argVal, bool):
          continue
        if argVal.lower() in ('yes', 'y', 'true'):
          specified_extra_args[argName] = True
        elif argVal.lower() in ('no', 'n', 'false'):
          specified_extra_args[argName] = False
        else:
          print(
            f"Invalid value {argVal} for argument {argName}",
            file=sys.stderr
          )
    specified_extra_args = \
      {k: (bool(v) if translator['extraArgs'][k]['type'] == 'flag' else v) \
       for k, v in specified_extra_args.items()}

    # assume defaults for unspecified extra args
    specified_extra_args.update(
      {n: (False if v['type'] == 'flag' else v['default']) \
        for n, v in translator['extraArgs'].items() \
        if n not in specified_extra_args}
    )
    return specified_extra_args

  def select_translator(self, translators):
    translatorsSorted = sorted(
      translators,
      key=lambda t: (
        not t['compatible'],
        ['pure', 'ifd', 'impure'].index(t['type'])
      )
    )
    option_translator = self.option("translator")
    if not option_translator:
      chosen = self.choice(
        'Select translator',
        list(map(
          lambda t: f"{t['subsystem']}.{t['type']}.{t['name']}{'  (compatible)' if t['compatible'] else ''}",
          translatorsSorted
        )),
        0
      )
      translator = list(filter(
        lambda t: [t['subsystem'], t['type'], t['name']] == chosen.split('  (')[0].split('.'),
        translatorsSorted,
      ))[0]
    else:
      translator = option_translator.split('.')
      try:
        if len(translator) == 3:
          translator = list(filter(
            lambda t: [t['subsystem'], t['type'], t['name']] == translator,
            translatorsSorted,
          ))[0]
        elif len(translator) == 1:
          translator = list(filter(
            lambda t: [t['name']] == translator,
            translatorsSorted,
          ))[0]
      except IndexError:
        print(f"Could not find translator '{'.'.join(translator)}'", file=sys.stderr)
        exit(1)
    return translator

  def parse_source(self, source):
    sourceSpec = {}
    # verify source
    if not source and not config['packagesDir']:
      sourcePath = os.path.realpath('./.')
      print(
        f"Source not specified. Defaulting to current directory: {source}",
        file=sys.stderr,
      )
    # check if source is a valid fetcher spec
    # handle source shortcuts
    elif source.partition(':')[0].split('+')[0] in os.environ.get("fetcherNames", None).split() \
        or source.startswith('http'):
      print(f"fetching source for '{source}'")
      sourceSpec = \
        callNixFunction("fetchers.translateShortcut", shortcut=source)
      subdir = ""
      if 'dir' in sourceSpec:
        subdir = '/' + sourceSpec['dir']
        del sourceSpec['dir']
      sourcePath = \
        buildNixFunction("fetchers.fetchSource", source=sourceSpec, extract=True)
      sourcePath += subdir
    # handle source paths
    else:
      # check if source path exists
      if not os.path.exists(source):
        print(f"Input source '{source}' does not exist", file=sys.stdout)
        exit(1)
      sourcePath = os.path.realpath(source)
      # handle source from dream-lock.json
      if sourcePath.endswith('dream-lock.json'):
        print(f"fetching source defined via existing dream-lock.json")
        with open(sourcePath) as f:
          sourceDreamLock = json.load(f)
        sourceDefaultPackage = sourceDreamLock['_generic']['defaultPackage']
        sourceDefaultPackageVersion = sourceDreamLock['_generic']['packages'][sourceDefaultPackage]
        sourceSpec = \
          sourceDreamLock['sources'][sourceDefaultPackage][sourceDefaultPackageVersion]
        sourcePath = \
          buildNixFunction("fetchers.fetchSource", source=sourceSpec, extract=True)
    return sourcePath, sourceSpec
