{
  lib,
  # dream2nix
  utils,
  ...
}: let
  b = builtins;

  subDreamLockNames = dreamLockFile: let
    dir = b.dirOf dreamLockFile;

    directories = utils.listDirs dir;

    dreamLockDirs =
      lib.filter
      (d: b.pathExists "${dir}/${d}/dream-lock.json")
      directories;
  in
    dreamLockDirs;

  readDreamLock = {dreamLock} @ args: let
    isFile =
      b.isPath dreamLock
      || b.isString dreamLock
      || lib.isDerivation dreamLock;

    lockMaybeCompressed =
      if isFile
      then b.fromJSON (b.readFile dreamLock)
      else dreamLock;

    lock =
      if lockMaybeCompressed.decompressed or false
      then lockMaybeCompressed
      else decompressDreamLock lockMaybeCompressed;

    subDreamLocks =
      if ! isFile
      then {}
      else let
        dir = b.dirOf dreamLock;
      in
        lib.genAttrs
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

    packageVersions =
      lib.mapAttrs
      (name: versions: lib.attrNames versions)
      dependencyGraph;

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
      if spec.type == "path"
      then {
        pname = spec.rootName;
        version = spec.rootVersion;
      }
      else {inherit pname version;};
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

      newDependencyGraph =
        lib.zipAttrsWith
        (name: versions:
          lib.zipAttrsWith
          (version: deps: lib.unique (lib.flatten deps))
          versions)
        [
          oldDependencyGraph
          inject
        ];
    in
      lib.recursiveUpdate lock {
        dependencies = newDependencyGraph;
      };

  decompressDependencyGraph = compGraph:
    lib.mapAttrs
    (name: versions:
      lib.mapAttrs
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
    lib.mapAttrs
    (name: versions:
      lib.mapAttrs
      (version: deps: map (dep: [dep.name dep.version]) deps)
      versions)
    decompGraph;

  decompressDreamLock = comp: let
    dependencyGraphDecomp =
      decompressDependencyGraph (comp.dependencies or {});

    cyclicDependencies =
      decompressDependencyGraph (comp.cyclicDependencies or {});

    emptyDependencyGraph =
      lib.mapAttrs
      (name: versions:
        lib.mapAttrs
        (version: source: [])
        versions)
      comp.sources;

    dependencyGraph =
      lib.recursiveUpdate
      emptyDependencyGraph
      dependencyGraphDecomp;
  in
    comp
    // {
      decompressed = true;
      cyclicDependencies = cyclicDependencies;
      dependencies = dependencyGraph;
    };

  compressDreamLock = uncomp: let
    dependencyGraphComp =
      compressDependencyGraph
      uncomp.dependencies;

    cyclicDependencies =
      compressDependencyGraph
      uncomp.cyclicDependencies;

    dependencyGraph =
      lib.filterAttrs
      (name: versions: versions != {})
      (lib.mapAttrs
        (name: versions:
          lib.filterAttrs
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
  inherit
    compressDreamLock
    decompressDreamLock
    decompressDependencyGraph
    getMainPackageSource
    getSource
    getSubDreamLock
    readDreamLock
    injectDependencies
    toJSON
    ;
}
