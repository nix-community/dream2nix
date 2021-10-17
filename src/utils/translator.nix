{
  lib,
  ...
}:
let

  b = builtins;

  simpleTranslate = translatorName:
    {
      mainPackageName,
      mainPackageVersion,
      mainPackageDependencies,
      buildSystemName,
      buildSystemAttrs,
      inputData,
      serializePackages,
      getOriginalID,
      getName,
      getVersion,
      getDependencies,
      getSourceType,
      sourceConstructors,

      mainPackageSource ? {
        type = "unknown";
      }
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
            mainPackageDependencies inputData;
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

          generic = {
            inherit dependencyGraph;
            buildSystem = buildSystemName;
            mainPackage = "${mainPackageName}#${mainPackageVersion}";
            sourcesCombinedHash = null;
            translator = translatorName;
          };

          # build system specific attributes
          buildSystem = buildSystemAttrs;
      };

in
  {
    inherit simpleTranslate;
  }

