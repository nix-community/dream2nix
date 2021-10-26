{
  lib,

  # dream2nix
  fetchers,
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

    in
      {
          sources = allSources;

          generic =
            {
              inherit mainPackageName mainPackageVersion;
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

