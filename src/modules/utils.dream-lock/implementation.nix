{config, ...}: let
  b = builtins;
  l = config.lib;

  replaceRootSources = {
    dreamLock,
    newSourceRoot,
  } @ args: let
    dreamLockLoaded = config.utils.dream-lock.readDreamLock {dreamLock = args.dreamLock;};
    iface = dreamLockLoaded.interface;
    patchVersion = version: source:
      if
        source.type
        == "path"
        && source.rootName == null
        && source.rootVersion == null
      then
        newSourceRoot
        // l.optionalAttrs (source ? relPath) {
          dir = source.relPath;
        }
      else source;

    patchedSources =
      l.recursiveUpdate
      {
        "${iface.defaultPackageName}"."${iface.defaultPackageVersion}" =
          newSourceRoot;
      }
      (
        l.mapAttrs
        (_: versions: l.mapAttrs patchVersion versions)
        dreamLock.sources
      );
  in
    dreamLock // {sources = patchedSources;};

  subDreamLockNames = dreamLockFile: let
    dir = b.dirOf dreamLockFile;

    directories = config.dlib.listDirs dir;

    dreamLockDirs =
      l.filter
      (d: b.pathExists "${dir}/${d}/dream-lock.json")
      directories;
  in
    dreamLockDirs;

  readDreamLock = {dreamLock} @ args: let
    isFile =
      b.isPath dreamLock
      || b.isString dreamLock
      || l.isDerivation dreamLock;

    lockMaybeCompressed =
      if isFile
      then b.fromJSON (b.readFile dreamLock)
      else dreamLock;

    lockRaw =
      if lockMaybeCompressed.decompressed or false
      then lockMaybeCompressed
      else decompressDreamLock lockMaybeCompressed;

    lock = extendWithEmptyGraph lockRaw;

    subDreamLocks =
      if ! isFile
      then {}
      else let
        dir = b.dirOf dreamLock;
      in
        l.genAttrs
        (subDreamLockNames dreamLock)
        (d:
          readDreamLock
          {dreamLock = "${dir}/${d}/dream-lock.json";});

    packages = lock._generic.packages;

    defaultPackageName = lock._generic.defaultPackage;
    defaultPackageVersion = packages."${defaultPackageName}";

    subsystemAttrs = lock._subsystem;

    sources = lock.sources;

    dependencyGraph = lock.dependencies;

    allDependencies = let
      candidatesList =
        l.unique
        (l.flatten
          (l.mapAttrsToList
            (name: versions:
              l.flatten (l.attrValues versions))
            dependencyGraph));
    in
      l.foldl'
      (all: new:
        all
        // {
          "${new.name}" = all.${new.name} or [] ++ [new.version];
        })
      {}
      candidatesList;

    allDependants =
      l.mapAttrs
      (name: versions: l.attrNames versions)
      dependencyGraph;

    packageVersions =
      l.zipAttrsWith
      (name: versions: l.flatten versions)
      [
        allDependants
        allDependencies
      ];

    cyclicDependencies = lock.cyclicDependencies;

    getSourceSpec = pname: version:
      sources."${pname}"."${version}"
      or (
        throw "The source spec for ${pname}#${version} is not defined in lockfile."
      );

    getDependencies = pname: version:
      b.filter
      (dep: ! b.elem dep cyclicDependencies."${pname}"."${version}" or [])
      dependencyGraph."${pname}"."${version}" or [];

    getCyclicDependencies = pname: version:
      cyclicDependencies."${pname}"."${version}" or [];

    getRoot = pname: version: let
      spec = getSourceSpec pname version;
    in
      if
        (pname == defaultPackageName && version == defaultPackageVersion)
        || spec.type != "path"
      then {inherit pname version;}
      else {
        pname = spec.rootName;
        version = spec.rootVersion;
      };
  in {
    inherit lock;
    interface = {
      inherit
        defaultPackageName
        defaultPackageVersion
        subsystemAttrs
        getCyclicDependencies
        getDependencies
        getSourceSpec
        getRoot
        packages
        packageVersions
        subDreamLocks
        ;
    };
  };

  getMainPackageSource = dreamLock:
    dreamLock
    .sources
    ."${dreamLock._generic.defaultPackage}"
    ."${dreamLock._generic.packages."${dreamLock._generic.defaultPackage}"}"
    // rec {
      pname = dreamLock._generic.defaultPackage;
      version = dreamLock._generic.packages."${pname}";
    };

  getSource = fetchedSources: pname: version:
    if
      fetchedSources
      ? "${pname}"."${version}"
      && fetchedSources."${pname}"."${version}" != "unknown"
    then fetchedSources."${pname}"."${version}"
    else
      throw ''
        The source for ${pname}#${version} is not defined.
        This can be fixed via an override. Example:
        ```
          dream2nix.make[Flake]Outputs {
            ...
            sourceOverrides = oldSources: {
              "${pname}"."${version}" = builtins.fetchurl { ... };
            };
            ...
          }
        ```
      '';

  # generate standalone dreamLock for a depenndency of an existing dreamLock
  getSubDreamLock = dreamLock: name: version: let
    lock = (readDreamLock {inherit dreamLock;}).lock;
  in
    lock
    // {
      _generic =
        lock._generic
        // {
          defaultPackage = name;
          packages =
            lock._generic.packages
            // {
              "${name}" = version;
            };
        };
    };

  injectDependencies = dreamLock: inject:
    if inject == {}
    then dreamLock
    else let
      lock = (readDreamLock {inherit dreamLock;}).lock;

      oldDependencyGraph = lock.dependencies;

      newDependcyGraph = decompressDependencyGraph inject;

      newDependencyGraph =
        l.zipAttrsWith
        (name: versions:
          l.zipAttrsWith
          (version: deps: l.unique (l.flatten deps))
          versions)
        [
          oldDependencyGraph
          newDependcyGraph
        ];
    in
      l.recursiveUpdate lock {
        dependencies = newDependencyGraph;
      };

  /*
  Ensures that there is an entry in dependencies for each source.
  This allows translators to omit creating dream-locks with empty
    dependency graph.
  */
  extendWithEmptyGraph = dreamLockDecomp: let
    emptyDependencyGraph =
      l.mapAttrs
      (name: versions:
        l.mapAttrs
        (version: source: [])
        versions)
      dreamLockDecomp.sources;

    dependencyGraph =
      l.recursiveUpdate
      emptyDependencyGraph
      dreamLockDecomp.dependencies;

    lock =
      dreamLockDecomp
      // {
        dependencies = dependencyGraph;
      };
  in
    lock;

  decompressDependencyGraph = compGraph:
    l.mapAttrs
    (name: versions:
      l.mapAttrs
      (version: deps:
        map
        (dep: {
          name = b.elemAt dep 0;
          version = b.elemAt dep 1;
        })
        deps)
      versions)
    compGraph;

  compressDependencyGraph = decompGraph:
    l.mapAttrs
    (name: versions:
      l.mapAttrs
      (version: deps: map (dep: [dep.name dep.version]) deps)
      versions)
    decompGraph;

  decompressDreamLock = comp: let
    dependencyGraphDecomp =
      decompressDependencyGraph (comp.dependencies or {});

    cyclicDependencies =
      decompressDependencyGraph (comp.cyclicDependencies or {});
  in
    comp
    // {
      decompressed = true;
      cyclicDependencies = cyclicDependencies;
      dependencies = dependencyGraphDecomp;
    };

  compressDreamLock = uncomp: let
    dependencyGraphComp =
      compressDependencyGraph
      uncomp.dependencies;

    cyclicDependencies =
      compressDependencyGraph
      uncomp.cyclicDependencies;

    dependencyGraph =
      l.filterAttrs
      (name: versions: versions != {})
      (l.mapAttrs
        (name: versions:
          l.filterAttrs
          (version: deps: deps != [])
          versions)
        dependencyGraphComp);
  in
    (b.removeAttrs uncomp ["decompressed"])
    // {
      inherit cyclicDependencies;
      dependencies = dependencyGraph;
    };

  toJSON = dreamLock: let
    lock =
      if dreamLock.decompressed or false
      then compressDreamLock dreamLock
      else dreamLock;

    json = b.toJSON lock;
  in
    json;
in {
  config.utils.dream-lock = {
    inherit
      compressDreamLock
      decompressDreamLock
      getMainPackageSource
      getSource
      getSubDreamLock
      readDreamLock
      replaceRootSources
      injectDependencies
      toJSON
      ;
  };
}
