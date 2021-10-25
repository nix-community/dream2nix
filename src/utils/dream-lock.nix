{
  lib,
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
        if b.isPath dreamLock || b.isString dreamLock then
          b.fromJSON (b.readFile dreamLock)
        else
          dreamLock;

      buildSystemAttrs = lock.buildSystem;

      sources = lock.sources;

      dependencyGraph = lock.generic.dependencyGraph;

      packageVersions =
        lib.mapAttrs
          (pname: versions: lib.attrNames versions)
          sources;

      dependenciesRemoved =
        lib.mapAttrs
          (name: versions:
            lib.mapAttrs
              (version: removedKeys:
                lib.forEach removedKeys
                  (rKey:
                    let
                      split = lib.splitString "#" rKey;
                      name = b.elemAt split 0;
                      version = b.elemAt split 1;
                    in
                      { inherit name version; }))
              versions)
          lock.generic.dependenciesRemoved;

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
              (dep:
                let
                  split = lib.splitString "#" dep;
                  name = b.elemAt split 0;
                  version = b.elemAt split 1;
                in
                  { inherit name version; }))
          dependencyGraph;

      getDependencies = pname: version:
        if dependenciesAttrs ? "${pname}#${version}" then
          dependenciesAttrs."${pname}#${version}"
        else
          [];

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

        allDependneciesOf = key:
          let
            next = lock.generic.dependencyGraph."${key}" or [];
          in
            next
            ++
            lib.flatten (b.map allDependneciesOf next);

        # use set for efficient lookups
        allDependenciesOfMainPackage =
          lib.genAttrs (allDependneciesOf "${name}#${version}") (x: null);

        newSources =
          lib.filterAttrs
            (p_name: versions: versions != {})
            (lib.mapAttrs
              (p_name: versions:
                lib.filterAttrs
                  (p_version: source:
                    allDependenciesOfMainPackage ? "${p_name}#${p_version}"
                    || (name == p_name && version == p_version))
                  versions)
              lock.sources);
        
        newDependencyGraph =
          lib.filterAttrs
            (key: deps:
              let
                split = lib.splitString "#" key;
                p_name = b.elemAt split 0;
                p_version = b.elemAt split 1;
              in
                allDependenciesOfMainPackage ? "${key}"
                ||
                (name == p_name && version == p_version))
            lock.generic.dependencyGraph;
      
      in
        lock // {
          generic = lock.generic // {
            mainPackageName = name;
            mainPackageVersion = version;
            dependencyGraph = newDependencyGraph;
          };
          sources = newSources;
        };

    filterFetchedSources = fetchedSources: dreamLock:
      let
        lockInterface = (readDreamLock { inherit dreamLock; }).interface;
        
        allDependencyKeys =
          lib.flatten
            (lib.mapAttrsToList
              (name: versions: lib.forEach versions
                (v: "${name}#${v}"))
              lockInterface.packageVersions);

        allDependencyKeysSet = lib.genAttrs allDependencyKeys (x: null);

      in
        lib.filterAttrs
          (key: source: allDependencyKeysSet ? "${key}")
          fetchedSources;
        
in
  {
    inherit
      getMainPackageSource
      filterFetchedSources
      getSource
      getSubDreamLock
      readDreamLock
    ;
  }
