{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;

  expectedFields = [
    "name"
    "version"
    "sourceSpec"
    "dependencies"
  ];

  mkFinalObjects = rawObjects: extractors:
    l.map
    (rawObj: let
      finalObj =
        {inherit rawObj;}
        // l.mapAttrs
        (key: extractFunc: extractFunc rawObj finalObj)
        extractors;
    in
      finalObj)
    rawObjects;

  # checks validity of all objects by iterating over them
  mkValidatedFinalObjects = finalObjects: translatorName: extraObjects:
    l.map
    (finalObj:
      if l.any (field: ! finalObj ? "${field}") expectedFields
      then
        throw
        ''
          Translator ${translatorName} failed.
          The following object does not contain all required fields:
          Object:
            ${l.toJSON finalObj}
          Missing fields:
            ${l.subtractLists expectedFields (l.attrNames finalObj)}
        ''
      # TODO: validate sourceSpec as well
      else finalObj)
    (finalObjects ++ extraObjects);

  mkExportedFinalObjects = finalObjects: exportedPackages:
    l.filter
    (finalObj:
      exportedPackages.${finalObj.name} or null == finalObj.version)
    finalObjects;

  mkRelevantFinalObjects = exportedFinalObjects: allDependencies:
    l.genericClosure {
      startSet =
        l.map
        (finalObj:
          finalObj
          // {key = "${finalObj.name}#${finalObj.version}";})
        exportedFinalObjects;
      operator = finalObj:
        l.map
        (c:
          allDependencies.${c.name}.${c.version}
          // {key = "${c.name}#${c.version}";})
        finalObj.dependencies;
    };

  /*
  format:
  {
    foo = {
      "1.0.0" = finalObj
    }
  }
  */
  makeDependencies = finalObjects:
    l.foldl'
    (result: finalObj:
      lib.recursiveUpdate
      result
      {
        "${finalObj.name}" = {
          "${finalObj.version}" = finalObj;
        };
      })
    {}
    finalObjects;

  translate = func: let
    final =
      func
      {
        inherit objectsByKey;
      };

    rawObjects = final.serializedRawObjects;

    finalObjects' = mkFinalObjects rawObjects final.extractors;

    objectsByKey =
      l.mapAttrs
      (key: keyFunc:
        l.foldl'
        (merged: finalObj:
          merged
          // {"${keyFunc finalObj.rawObj finalObj}" = finalObj;})
        {}
        finalObjects')
      final.keys;

    dreamLockData = magic final;

    magic = {
      defaultPackage,
      exportedPackages,
      extractors,
      extraObjects ? [],
      keys ? {},
      location ? "",
      serializedRawObjects,
      subsystemName,
      subsystemAttrs ? {},
      translatorName,
    }: let
      inputs = {
        inherit
          defaultPackage
          exportedPackages
          extractors
          extraObjects
          keys
          location
          serializedRawObjects
          subsystemName
          subsystemAttrs
          translatorName
          ;
      };

      finalObjects =
        mkValidatedFinalObjects
        finalObjects'
        translatorName
        (final.extraObjects or []);

      allDependencies = makeDependencies finalObjects;

      exportedFinalObjects =
        mkExportedFinalObjects finalObjects exportedPackages;

      relevantFinalObjects =
        mkRelevantFinalObjects exportedFinalObjects allDependencies;

      relevantDependencies = makeDependencies relevantFinalObjects;

      sources =
        l.mapAttrs
        (name: versions: let
          # Filter out all `path` sources which link to store paths.
          # The removed sources can be added back via source override later
          filteredObjects =
            l.filterAttrs
            (version: finalObj:
              (finalObj.sourceSpec.type != "path")
              || ! l.isStorePath (l.removeSuffix "/" finalObj.sourceSpec.path))
            versions;
        in
          l.mapAttrs
          (version: finalObj: finalObj.sourceSpec)
          filteredObjects)
        relevantDependencies;

      dependencyGraph =
        lib.mapAttrs
        (name: versions:
          lib.mapAttrs
          (version: finalObj: finalObj.dependencies)
          versions)
        relevantDependencies;

      cyclicDependencies = import ./getCycles.nix {inherit lib dependencyGraph;};

      data =
        {
          decompressed = true;

          _generic = {
            inherit
              defaultPackage
              location
              ;
            packages = exportedPackages;
            subsystem = subsystemName;
            sourcesAggregatedHash = null;
          };

          # build system specific attributes
          _subsystem = subsystemAttrs;

          inherit cyclicDependencies sources;
        }
        // {dependencies = dependencyGraph;};
    in {
      inherit data;
      inherit inputs;
    };
  in {
    result = dreamLockData.data;
    inputs = dreamLockData.inputs;
  };
in {
  inherit
    translate
    mkFinalObjects
    mkExportedFinalObjects
    mkRelevantFinalObjects
    makeDependencies
    ;
}
