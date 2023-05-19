{lib, ...}: let
  l = builtins // lib;

  listDirs = path: l.attrNames (l.filterAttrs (n: v: v == "directory") (builtins.readDir path));

  subDreamLockNames = dreamLockFile: let
    dir = l.dirOf dreamLockFile;

    directories = listDirs dir;

    dreamLockDirs =
      l.filter
      (d: l.pathExists "${dir}/${d}/dream-lock.json")
      directories;
  in
    dreamLockDirs;

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
          name = l.elemAt dep 0;
          version = l.elemAt dep 1;
        })
        deps)
      versions)
    compGraph;

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

  readDreamLock = {dreamLock} @ args: let
    isFile =
      l.isPath dreamLock
      || l.isString dreamLock
      || l.isDerivation dreamLock;

    lockMaybeCompressed =
      if isFile
      then l.fromJSON (l.readFile dreamLock)
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
        dir = l.dirOf dreamLock;
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
      (name: versions: l.unique (l.flatten versions))
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
      l.filter
      (dep: ! l.elem dep cyclicDependencies."${pname}"."${version}" or [])
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
in
  readDreamLock
