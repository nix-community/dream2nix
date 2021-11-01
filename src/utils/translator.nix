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
      buildSystemName,
      buildSystemAttrs,

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
        (result: pkgData: lib.recursiveUpdate result {
          "${getName pkgData}" = {
            "${getVersion pkgData}" =
              let
                type = getSourceType pkgData;
                constructedArgs = 
                  (sourceConstructors."${type}" pkgData)
                  // { inherit type; };
              in
                fetchers.constructSource constructedArgs;
          };
        })
        {}
        serializedPackagesList;
      
      dependencyGraph =
        {
          "${mainPackageName}#${mainPackageVersion}" =
            lib.forEach mainPackageDependencies
              (dep: "${dep.name}#${dep.version}");
        }
        //
        lib.listToAttrs
          (lib.forEach
            serializedPackagesList
            (pkgData: lib.nameValuePair
              "${getName pkgData}#${getVersion pkgData}"
              (b.map
                (depNameVer: "${depNameVer.name}#${depNameVer.version}")
                (getDependencies pkgData getDepByNameVer dependenciesByOriginalID))));
      
      allDependencyKeys =
        lib.attrNames
          (lib.genAttrs
            (b.foldl'
              (a: b: a ++ b)
              []
              (lib.attrValues dependencyGraph))
            (x: null));
      
      missingDependencies =
        lib.flatten
          (lib.forEach allDependencyKeys
            (depKey:
              let
                split = lib.splitString "#" depKey;
                name = b.elemAt split 0;
                version = b.elemAt split 1;
              in
                if sources ? "${name}" && sources."${name}" ? "${version}" then
                  []
                else
                  { inherit name version; }));

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
        let
          findCycles = node: prevNodes: cycles:
            let
              children = dependencyGraph."${node}";
              cyclicChildren = lib.filter (child: prevNodes ? "${child}") children;
              nonCyclicChildren = lib.filter (child: ! prevNodes ? "${child}") children;
              cycles' =
                cycles
                ++
                (b.map (child: { from = node; to = child; }) cyclicChildren);
              prevNodes' = prevNodes // { "${node}" = null; };
            in
              if nonCyclicChildren == [] then
                cycles'
              else
                lib.flatten
                  (b.map
                    (child: findCycles child prevNodes' cycles')
                    nonCyclicChildren);

          cyclesList = findCycles "${mainPackageName}#${mainPackageVersion}" {} [];
        in
          b.foldl'
            (cycles: cycle:
              let
                fromNameVersion = utils.keyToNameVersion cycle.from;
                fromName = fromNameVersion.name;
                fromVersion = fromNameVersion.version;
                toNameVersion = utils.keyToNameVersion cycle.to;
                toName = toNameVersion.name;
                toVersion = toNameVersion.version;
                reverse = (cycles."${toName}"."${toVersion}" or []);
              in
                # if reverse edge already in cycles, do nothing
                if b.elem cycle.from reverse then
                  cycles
                else
                  lib.recursiveUpdate
                    cycles
                    {
                      "${fromName}"."${fromVersion}" =
                        let
                          existing = cycles."${fromName}"."${fromVersion}" or [];
                        in
                          if b.elem cycle.to existing then
                            existing
                          else
                            existing ++ [ cycle.to ];
                    })
            {}
            cyclesList;

    in
      {
          sources = allSources;

          generic =
            {
              inherit
                cyclicDependencies
                mainPackageName
                mainPackageVersion
              ;
              buildSystem = buildSystemName;
              sourcesCombinedHash = null;
              translator = translatorName;
            }
            //
            (lib.optionalAttrs (getDependencies != null) { inherit dependencyGraph; });

          # build system specific attributes
          buildSystem = buildSystemAttrs;
      };

in
  {
    inherit simpleTranslate;
  }

