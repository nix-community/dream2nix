{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;

  simpleTranslate2 = func: let
    final =
      func
      {
        inherit objectsByKey;
      };

    rawObjects = final.serializedRawObjects;

    expectedFields = [
      "name"
      "version"
      "sourceSpec"
      "dependencies"
    ];

    finalObjects' =
      l.map
      (rawObj: let
        finalObj =
          {inherit rawObj;}
          // l.mapAttrs
          (key: extractFunc: extractFunc rawObj finalObj)
          final.extractors;
      in
        finalObj)
      rawObjects;

    # checks validity of all objects by iterating over them
    finalObjects =
      l.map
      (finalObj:
        if l.any (field: ! finalObj ? "${field}") expectedFields
        then
          throw
          ''
            Translator ${final.translatorName} failed.
            The following object does not contain all required fields:
            Object:
              ${l.toJSON finalObj}
            Missing fields:
              ${l.subtractLists expectedFields (l.attrNames finalObj)}
          ''
        # TODO: validate sourceSpec as well
        else finalObj)
      (finalObjects' ++ (final.extraObjects or []));

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
      extraDependencies ? {},
      extraObjects ? [],
      keys ? {},
      location ? "",
      serializedRawObjects,
      subsystemName,
      subsystemAttrs ? {},
      translatorName,
    }: let
      allDependencies =
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

      sources =
        l.mapAttrs
        (name: versions:
          l.mapAttrs
          (version: finalObj: finalObj.sourceSpec)
          versions)
        allDependencies;

      dependencyGraph = let
        depGraph =
          lib.mapAttrs
          (name: versions:
            lib.mapAttrs
            (version: finalObj: finalObj.dependencies)
            versions)
          allDependencies;
      in
        # add extraDependencies to dependency graph
        l.foldl'
        (all: new:
          all
          // {
            "${new.name}" =
              all."${new.name}"
              or {}
              // {
                "${new.version}" =
                  all."${new.name}"."${new.version}"
                  or []
                  ++ new.dependencies;
              };
          })
        depGraph
        extraDependencies;

      cyclicDependencies =
        # TODO: inefficient! Implement some kind of early cutoff
        let
          depGraphWithFakeRoot =
            l.recursiveUpdate
            dependencyGraph
            {
              __fake-entry.__fake-version =
                l.mapAttrsToList
                dlib.nameVersionPair
                exportedPackages;
            };

          findCycles = node: prevNodes: cycles: let
            children =
              depGraphWithFakeRoot."${node.name}"."${node.version}";

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
              ++ (l.map (child: {
                  from = node;
                  to = child;
                })
                cyclicChildren);

            # use set for efficient lookups
            prevNodes' =
              prevNodes
              // {"${node.name}#${node.version}" = null;};
          in
            if nonCyclicChildren == []
            then cycles'
            else
              lib.flatten
              (l.map
                (child: findCycles child prevNodes' cycles')
                nonCyclicChildren);

          cyclesList =
            findCycles
            (dlib.nameVersionPair
              "__fake-entry"
              "__fake-version")
            {}
            [];
        in
          l.foldl'
          (cycles: cycle: (
            let
              existing =
                cycles."${cycle.from.name}"."${cycle.from.version}"
                or [];

              reverse =
                cycles."${cycle.to.name}"."${cycle.to.version}"
                or [];
            in
              # if edge or reverse edge already in cycles, do nothing
              if
                l.elem cycle.from reverse
                || l.elem cycle.to existing
              then cycles
              else
                lib.recursiveUpdate
                cycles
                {
                  "${cycle.from.name}"."${cycle.from.version}" =
                    existing ++ [cycle.to];
                }
          ))
          {}
          cyclesList;
    in
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
  in
    dreamLockData;
in {
  inherit simpleTranslate2;
}
