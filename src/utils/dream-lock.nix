{
  lib,

  # dream2nix
  utils,
  ...
}:
let

  b = builtins;

  readDreamLock = 
    {
      dreamLock,
    }@args:
    let

      lock =
        if b.isPath dreamLock
            || b.isString dreamLock
            || lib.isDerivation dreamLock then
          b.fromJSON (b.readFile dreamLock)
        else
          dreamLock;

      buildSystemAttrs = lock.buildSystem;

      sources = lock.sources;

      dependencyGraph = lock.generic.dependencyGraph;

      packageVersions =
        let
          allDependencyKeys =
            lib.attrNames
              (lib.genAttrs
                (lib.flatten
                  ((lib.attrValues dependencyGraph) ++ (lib.attrNames dependencyGraph)))
                (x: null));
        in
          lib.foldl'
            (packageVersions: dep:
              packageVersions // {
                "${dep.name}" = (packageVersions."${dep.name}" or []) ++ [
                  dep.version
                ];
              })
            {}
            (b.map (utils.keyToNameVersion) allDependencyKeys);

      dependenciesRemoved =
        lib.mapAttrs
          (name: versions:
            lib.mapAttrs
              (version: removedKeys:
                lib.forEach removedKeys
                  (rKey: utils.keyToNameVersion rKey))
              versions)
          lock.generic.dependenciesRemoved or {};

      # Format:
      # {
      #   "{name}#{version}": [
      #     { name=...; version=...; }
      #     { name=...; version=...; }
      #   ]
      # }
      dependenciesAttrs =
        lib.mapAttrs
          (key: deps:
            lib.forEach deps
              (dep: utils.keyToNameVersion dep))
          dependencyGraph;

      getDependencies = pname: version:
        if dependenciesAttrs ? "${pname}#${version}" then
          # filter out cyclicDependencies
          lib.filter
            (dep: ! b.elem dep (dependenciesRemoved."${pname}"."${version}" or []))
            dependenciesAttrs."${pname}#${version}"
        # assume no deps if package not found in dependencyGraph
        else
          [];
      
      getCyclicDependencies = pname: version:
        dependenciesRemoved."${pname}"."${version}" or [];

    in
      {
        inherit lock;
        interface = rec {

          inherit (lock.generic)
            mainPackageName
            mainPackageVersion
          ;

          inherit
            buildSystemAttrs
            dependenciesRemoved
            getCyclicDependencies
            getDependencies
            packageVersions
          ;
        };
      };

  getMainPackageSource = dreamLock:
    dreamLock.sources
      ."${dreamLock.generic.mainPackageName}"
      ."${dreamLock.generic.mainPackageVersion}";

  getSource = fetchedSources: pname: version:
    let
      key = "${pname}#${version}";
    in
      if fetchedSources ? "${key}" then
        fetchedSources."${key}"
      else
        throw ''
          The source for ${key} is not defined.
          This can be fixed via an override. Example:
          ```
            dream2nix.riseAndShine {
              ...
              sourceOverrides = oldSources: {
                "${key}" = builtins.fetchurl { ... };
              };
              ...
            }
          ```
        '';

    # generate standalone dreamLock for a depenndency of an existing dreamLock
    getSubDreamLock = dreamLock: name: version:
      let
        lock = (readDreamLock { inherit dreamLock; }).lock;
      
      in
        lock // {
          generic = lock.generic // {
            mainPackageName = name;
            mainPackageVersion = version;
          };
        };

    injectDependencies = dreamLock: inject:
      if inject == {} then dreamLock else
      let
        lock = (readDreamLock { inherit dreamLock; }).lock;

        oldDependencyGraph = lock.generic.dependencyGraph;
        
        newDependencyGraph =
          lib.mapAttrs
            (key: deps:
              let
                nameVer = utils.keyToNameVersion key;
              in
                deps
                ++
                (if inject ? "${nameVer.name}"."${nameVer.version}" then
                  (b.map
                    utils.nameVersionToKey
                    inject."${nameVer.name}"."${nameVer.version}")
                else
                  []))
            oldDependencyGraph;

      in
        lib.recursiveUpdate lock {
          generic.dependencyGraph = newDependencyGraph;
        };

in
  {
    inherit
      getMainPackageSource
      getSource
      getSubDreamLock
      readDreamLock
      injectDependencies
    ;
  }
