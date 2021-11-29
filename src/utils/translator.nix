{
  lib,

  # dream2nix
  fetchers,
  utils,
  ...
}:
let

  b = builtins;

  simpleTranslate = translatorName:
    {
      # values
      inputData,
      mainPackageName,
      mainPackageVersion,
      mainPackageDependencies,
      subsystemName,
      subsystemAttrs,

      # functions
      serializePackages,
      getName,
      getVersion,
      getSourceType,
      sourceConstructors,
      createMissingSource ? (name: version: { type = "unknown"; }),
      getDependencies ? null,
      getOriginalID ? null,
      mainPackageSource ? { type = "unknown"; },
    }:
    let

      serializedPackagesList = serializePackages inputData;

      allDependencies = b.foldl'
        (result: pkgData: lib.recursiveUpdate result {
          "${getName pkgData}" = {
            "${getVersion pkgData}" = pkgData;
          };
        })
        {}
        serializedPackagesList;

      dependenciesByOriginalID = b.foldl'
        (result: pkgData: lib.recursiveUpdate result {
          "${getOriginalID pkgData}" = pkgData;
        })
        {}
        serializedPackagesList;

      sources = b.foldl'
        (result: pkgData:
        let
          pkgName = getName pkgData;
          pkgVersion = getVersion pkgData;
        in lib.recursiveUpdate result {
            "${pkgName}" = {
                "${pkgVersion}" =
                  let
                    type = getSourceType pkgData;
                    constructedArgs =
                      (sourceConstructors."${type}" pkgData)
                      // {
                        inherit type;
                        dependencyInfo = {
                          pname = pkgName;
                          version = pkgVersion;
                        };
                     };
                  in
                    fetchers.constructSource constructedArgs;
              };
           })
        {}
        serializedPackagesList;

      dependencyGraph =
        let
          depGraph =
            (lib.mapAttrs
              (name: versions:
                lib.mapAttrs
                  (version: pkgData:
                    getDependencies
                      pkgData
                      getDepByNameVer
                      dependenciesByOriginalID)
                  versions)
              allDependencies);
        in
          depGraph // {
            "${mainPackageName}" = depGraph."${mainPackageName}" or {} // {
              "${mainPackageVersion}" = mainPackageDependencies;
            };
          };

      allDependencyKeys =
        let
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
              if sources ? "${dep.name}"."${dep.version}" then
                []
              else
                dep));

      generatedSources =
        if missingDependencies == [] then
          {}
        else
          lib.listToAttrs
            (b.map
              (dep: lib.nameValuePair
                "${dep.name}"
                {
                  "${dep.version}" =
                    createMissingSource dep.name dep.version;
                })
              missingDependencies);

      allSources =
        lib.recursiveUpdate sources generatedSources;

      getDepByNameVer = name: version:
        allDependencies."${name}"."${version}";

      cyclicDependencies =
        # TODO: inefficient! Implement some kind of early cutoff
        let
          findCycles = node: prevNodes: cycles:
            let

              children = dependencyGraph."${node.name}"."${node.version}";

              cyclicChildren =
                lib.filter
                  (child: prevNodes ? "${child.name}#${child.version}")
                  children;

              nonCyclicChildren =
                lib.filter
                  (child: ! prevNodes ? "${child.name}#${child.version}")
                  children;

              cycles' =
                cycles
                ++
                (b.map (child: { from = node; to = child; }) cyclicChildren);

              # use set for efficient lookups
              prevNodes' =
                prevNodes
                // { "${node.name}#${node.version}" = null; };

            in
              if nonCyclicChildren == [] then
                cycles'
              else
                lib.flatten
                  (b.map
                    (child: findCycles child prevNodes' cycles')
                    nonCyclicChildren);

          cyclesList =
            findCycles
              (utils.nameVersionPair mainPackageName mainPackageVersion)
              {}
              [];
        in
          b.foldl'
            (cycles: cycle:
              (
              let
                existing =
                  cycles."${cycle.from.name}"."${cycle.from.version}"
                  or [];

                reverse =
                  cycles."${cycle.to.name}"."${cycle.to.version}"
                  or [];

              in
                # if edge or reverse edge already in cycles, do nothing
                if b.elem cycle.from reverse
                    || b.elem cycle.to existing then
                  cycles
                else
                  lib.recursiveUpdate
                    cycles
                    {
                      "${cycle.from.name}"."${cycle.from.version}" =
                        existing ++ [ cycle.to ];
                    }))
            {}
            cyclesList;

    in
      {
        decompressed = true;

        _generic =
          {
            inherit
              mainPackageName
              mainPackageVersion
            ;
            subsystem = subsystemName;
            sourcesAggregatedHash = null;
            translator = translatorName;
          };

        # build system specific attributes
        _subsystem = subsystemAttrs;

        inherit cyclicDependencies;

        sources = allSources;
      }
      //
      (lib.optionalAttrs
        (getDependencies != null)
        { dependencies = dependencyGraph; });

in
  {
    inherit simpleTranslate;
  }

