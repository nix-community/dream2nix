{
  lib,
  # dream2nix
  fetchers,
  dlib,
  ...
}: let
  b = builtins;

  overrideWarning = fields: args:
    lib.filterAttrs (
      name: _:
        if lib.any (field: name == field) fields
        then
          lib.warn ''
            you are trying to pass a "${name}" key from your source
            constructor, this will be overridden with a value passed
            by dream2nix.
          ''
          false
        else true
    )
    args;

  simpleTranslate = func: let
    final =
      func
      {
        inherit getDepByNameVer;
        inherit dependenciesByOriginalID;
      };

    getDepByNameVer = name: version:
      final.allDependencies."${name}"."${version}" or null;

    dependenciesByOriginalID =
      b.foldl'
      (result: pkgData:
        lib.recursiveUpdate result {
          "${final.getOriginalID pkgData}" = pkgData;
        })
      {}
      serializedPackagesList;

    serializedPackagesList = final.serializePackages final.inputData;

    dreamLockData = magic final;

    magic = {
      # values
      defaultPackage,
      inputData,
      location ? "",
      mainPackageDependencies,
      packages,
      subsystemName,
      subsystemAttrs,
      translatorName,
      # functions
      serializePackages,
      getName,
      getVersion,
      getSourceType,
      sourceConstructors,
      createMissingSource ? (name: version: throw "Cannot find source for ${name}:${version}"),
      getDependencies ? null,
      getOriginalID ? null,
      mainPackageSource ? {type = "unknown";},
    }: let
      allDependencies =
        b.foldl'
        (result: pkgData:
          lib.recursiveUpdate result {
            "${getName pkgData}" = {
              "${getVersion pkgData}" = pkgData;
            };
          })
        {}
        serializedPackagesList;

      sources =
        b.foldl'
        (result: pkgData: let
          pkgName = getName pkgData;
          pkgVersion = getVersion pkgData;
          type = getSourceType pkgData;
          constructedArgs = sourceConstructors."${type}" pkgData;

          constructedArgsKeep =
            overrideWarning ["pname" "version"] constructedArgs;

          constructedSource = fetchers.constructSource (constructedArgsKeep
            // {
              inherit type;
              pname = pkgName;
              version = pkgVersion;
            });

          skip =
            (type == "path")
            && lib.isStorePath (lib.removeSuffix "/" constructedArgs.path);
        in
          if skip
          then result
          else
            lib.recursiveUpdate result {
              "${pkgName}" = {
                "${pkgVersion}" =
                  b.removeAttrs constructedSource ["pname" "version"];
              };
            })
        {}
        serializedPackagesList;

      dependencyGraph = let
        depGraph =
          lib.mapAttrs
          (name: versions:
            lib.mapAttrs
            (version: pkgData: getDependencies pkgData)
            versions)
          allDependencies;
      in
        depGraph
        // {
          "${defaultPackage}" =
            depGraph."${defaultPackage}"
            or {}
            // {
              "${packages."${defaultPackage}"}" = mainPackageDependencies;
            };
        };

      allDependencyKeys = let
        depsWithDuplicates =
          lib.flatten
          (lib.flatten
            (lib.mapAttrsToList
              (name: versions: lib.attrValues versions)
              dependencyGraph));
      in
        lib.unique depsWithDuplicates;

      missingDependencies =
        lib.flatten
        (lib.forEach allDependencyKeys
          (dep:
            if sources ? "${dep.name}"."${dep.version}"
            then []
            else dep));

      generatedSources =
        if missingDependencies == []
        then {}
        else
          lib.listToAttrs
          (b.map
            (dep:
              lib.nameValuePair
              "${dep.name}"
              {
                "${dep.version}" =
                  createMissingSource dep.name dep.version;
              })
            missingDependencies);

      allSources =
        lib.recursiveUpdate sources generatedSources;

      cyclicDependencies = import ../lib/getCycles.nix {inherit lib dependencyGraph;};
    in
      {
        decompressed = true;

        _generic = {
          inherit
            defaultPackage
            location
            packages
            ;
          subsystem = subsystemName;
          sourcesAggregatedHash = null;
        };

        # build system specific attributes
        _subsystem = subsystemAttrs;

        inherit cyclicDependencies;

        sources = allSources;
      }
      // (lib.optionalAttrs
        (getDependencies != null)
        {dependencies = dependencyGraph;});
  in
    dreamLockData;
in {
  inherit simpleTranslate;
}
