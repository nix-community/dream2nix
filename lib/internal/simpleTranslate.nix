# This is currently only used for legacy modules ported to v1.
# The dream-lock concept might be deprecated together with this module at some
#   point.
{lib, ...}: let
  l = builtins // lib;

  nameVersionPair = name: version: {inherit name version;};

  overrideWarning = fields: args:
    l.filterAttrs (
      name: _:
        if l.any (field: name == field) fields
        then
          l.warn ''
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
      l.foldl'
      (result: pkgData:
        l.recursiveUpdate result {
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
        l.foldl'
        (result: pkgData:
          l.recursiveUpdate result {
            "${getName pkgData}" = {
              "${getVersion pkgData}" = pkgData;
            };
          })
        {}
        serializedPackagesList;

      sources =
        l.foldl'
        (result: pkgData: let
          pkgName = getName pkgData;
          pkgVersion = getVersion pkgData;
          type = getSourceType pkgData;
          constructedArgs = sourceConstructors."${type}" pkgData;

          constructedArgsKeep =
            overrideWarning ["pname" "version"] constructedArgs;

          constructedSource =
            constructedArgsKeep
            // {
              inherit type;
              pname = pkgName;
              version = pkgVersion;
            };

          skip =
            (type == "path")
            && l.isStorePath (l.removeSuffix "/" constructedArgs.path);
        in
          if skip
          then result
          else
            l.recursiveUpdate result {
              "${pkgName}" = {
                "${pkgVersion}" =
                  l.removeAttrs constructedSource ["pname" "version"];
              };
            })
        {}
        serializedPackagesList;

      dependencyGraph = let
        depGraph =
          l.mapAttrs
          (name: versions:
            l.mapAttrs
            (version: getDependencies)
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
          l.flatten
          (l.flatten
            (l.mapAttrsToList
              (name: versions: l.attrValues versions)
              dependencyGraph));
      in
        l.unique depsWithDuplicates;

      missingDependencies =
        l.flatten
        (l.forEach allDependencyKeys
          (dep:
            if sources ? "${dep.name}"."${dep.version}"
            then []
            else dep));

      generatedSources =
        if missingDependencies == []
        then {}
        else
          l.listToAttrs
          (l.map
            (dep:
              l.nameValuePair
              "${dep.name}"
              {
                "${dep.version}" =
                  createMissingSource dep.name dep.version;
              })
            missingDependencies);

      allSources =
        l.recursiveUpdate sources generatedSources;

      cyclicDependencies =
        # TODO: inefficient! Implement some kind of early cutoff
        let
          findCycles = node: prevNodes: cycles: let
            children = dependencyGraph."${node.name}"."${node.version}";

            cyclicChildren =
              l.filter
              (child: prevNodes ? "${child.name}#${child.version}")
              children;

            nonCyclicChildren =
              l.filter
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
              l.flatten
              (l.map
                (child: findCycles child prevNodes' cycles')
                nonCyclicChildren);

          cyclesList =
            findCycles
            (nameVersionPair defaultPackage packages."${defaultPackage}")
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
                l.recursiveUpdate
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
      // (l.optionalAttrs
        (getDependencies != null)
        {dependencies = dependencyGraph;});
  in
    dreamLockData;
in
  simpleTranslate
