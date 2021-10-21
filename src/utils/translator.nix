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

      allDependenciesByOriginalID = b.foldl'
        (result: pkgData: lib.recursiveUpdate result {
          "${getOriginalID pkgData}" = pkgData;
        })
        {}
        serializedPackagesList;

      sources = b.foldl'
        (result: pkgData: lib.recursiveUpdate result {
          "${getName pkgData}#${getVersion pkgData}" =
            let
              type = getSourceType pkgData;
              constructedArgs = 
                (sourceConstructors."${type}" pkgData)
                // { inherit type; };
            in
              fetchers.constructSource constructedArgs;
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
                (getDependencies pkgData getDepByNameVer getDepByOriginalID))));
      
      getDepByOriginalID = id:
        allDependenciesByOriginalID."${id}";
      
      getDepByNameVer = name: version:
        allDependencies."${name}"."${version}";

    in
      {
          inherit sources;

          generic =
            {
              buildSystem = buildSystemName;
              mainPackage = "${mainPackageName}#${mainPackageVersion}";
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

