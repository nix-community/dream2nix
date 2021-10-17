{
  lib,
  ...
}:
let

  b = builtins;

  simpleTranslate = translatorName:
    {
      # values
      mainPackageName,
      mainPackageVersion,
      mainPackageDependencies,
      buildSystemName,
      buildSystemAttrs,
      inputData,

      # functions
      serializePackages,
      getName,
      getVersion,
      getSourceType,
      sourceConstructors,
      getOriginalID ? null,
      getDependencies ? null,
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
            sourceConstructors."${getSourceType pkgData}" pkgData;
        })
        {}
        serializedPackagesList;
      
      dependencyGraph =
        {
          "${mainPackageName}#${mainPackageVersion}" =
            lib.forEach (mainPackageDependencies inputData)
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

