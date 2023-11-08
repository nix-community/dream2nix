{
  lib,
  parseSpdxId,
  sanitizePath,
  sanitizeRelativePath,
  simpleTranslate2,
  ...
}: let
  l = lib // builtins;

  translate = {
    # project,
    projectRelPath,
    tree,
    ...
  }: let
    # get the root source and project source
    rootTree = tree;
    projectTree = rootTree.getNodeFromPath projectRelPath;
    rootSource = rootTree.fullPath;
    projectSource = sanitizePath "${rootSource}/${projectRelPath}";
    # find all of the crates
    # this is used while resolving path dependencies
    allCrates =
      (import ./findAllCrates.nix {inherit lib;})
      {tree = rootTree;};

    # Get the root toml
    rootToml = {
      relPath = projectRelPath;
      value = projectTree.files."Cargo.toml".tomlContent;
    };
    workspacePackage = rootToml.value.workspace.package or null;
    # get a package attribute, handles `attr.workspace = true`
    # where the attribute is instead defined in workspace metadata
    getPackageAttribute = package: attr:
      if package.${attr}.workspace or false
      then workspacePackage.${attr} or (l.throw "no workspace ${attr} found in root Cargo.toml for ${package.name}")
      else package.${attr} or (l.throw "no ${attr} found in Cargo.toml for ${package.name}");
    getVersion = package: getPackageAttribute package "version";
    getLicense = package: getPackageAttribute package "license";

    # find all the workspace members if we are in a workspace
    # this is used to figure out what packages we can build
    # and while resolving path dependencies
    workspaceMembers =
      l.flatten
      (
        l.map
        (
          memberName: let
            components = l.splitString "/" memberName;
          in
            # Resolve globs if there are any
            if l.last components == "*"
            then let
              parentDirRel = l.concatStringsSep "/" (l.init components);
              dirs = (rootTree.getNodeFromPath parentDirRel).directories;
            in
              l.mapAttrsToList
              (name: _: "${parentDirRel}/${name}")
              dirs
            else memberName
        )
        (rootToml.value.workspace.members or [])
      );
    # Get cargo packages (for workspace members)
    workspaceCargoPackages =
      l.map
      (relPath: {
        inherit relPath;
        value = (projectTree.getNodeFromPath "${relPath}/Cargo.toml").tomlContent;
      })
      # Filter root referencing member, we already parsed this (rootToml)
      (l.filter (relPath: relPath != ".") workspaceMembers);

    # All cargo packages that we will output
    cargoPackages =
      if l.hasAttrByPath ["package" "name"] rootToml.value
      # Note: the ordering is important here, since packageToml assumes
      # the rootToml to be at 0 index (if it is a package)
      then [rootToml] ++ workspaceCargoPackages
      else workspaceCargoPackages;

    # Get a "main" package toml
    packageToml = l.elemAt cargoPackages 0;

    # Parse Cargo.lock and extract dependencies
    parsedLock = projectTree.files."Cargo.lock".tomlContent;
    parsedDeps = parsedLock.package;

    makeDepId = dep: "${dep.name} ${dep.version} (${dep.source or ""})";

    # Gets a checksum from the [metadata] table of the lockfile
    getChecksum = dep: parsedLock.metadata."checksum ${makeDepId dep}";

    # map of dependency names to a list of the possible versions
    depNamesToVersions =
      l.foldl'
      (
        all: el:
          if l.hasAttr el.name all
          then all // {${el.name} = all.${el.name} ++ [el];}
          else all // {${el.name} = [el];}
      )
      {}
      parsedDeps;
    # takes a parsed dependency entry and finds the original dependency from `Cargo.lock`
    findOriginalDep = let
      # checks dep against another dep to see if they are the same
      # this is only for checking entries from a `dependencies` list
      # against a dependency entry under `package` from Cargo.lock
      isSameDependency = dep: againstDep:
        l.foldl'
        (previousResult: result: previousResult && result)
        true
        (
          l.mapAttrsToList
          (
            name: value:
              if l.hasAttr name againstDep
              then
                # if git source, we need to get rid of the revision part
                if name == "source" && l.hasPrefix "git+" againstDep.source
                then l.concatStringsSep "#" (l.init (l.splitString "#" againstDep.source)) == value
                else againstDep.${name} == value
              else false
          )
          dep
        );
    in
      dep: let
        notFoundError = "no dependency found with name ${dep.name} in Cargo.lock";
        foundCount = l.length depNamesToVersions.${dep.name};
        found =
          # if found one version, then that's the dependency we are looking for
          if foundCount == 1
          then l.head depNamesToVersions.${dep.name}
          # if found multiple, then we need to check which dependency we are looking for
          else if foundCount > 1
          then
            l.findFirst
            (otherDep: isSameDependency dep otherDep)
            (throw notFoundError)
            depNamesToVersions.${dep.name}
          else throw notFoundError;
      in
        found;
    # This parses a "package-name version (source)" entry in the "dependencies"
    # field of a dependency in Cargo.lock
    parseDepEntryImpl = entry: let
      parsed = l.splitString " " entry;
      # name is always at the beginning
      name = l.head parsed;
      # parse the version if it exists
      maybeVersion =
        if l.length parsed > 1
        then l.elemAt parsed 1
        else null;
      # parse the source if it exists
      source =
        if l.length parsed > 2
        then l.removePrefix "(" (l.removeSuffix ")" (l.elemAt parsed 2))
        else null;
      # find the original dependency from the information we have
      foundDep = findOriginalDep (
        {inherit name;}
        // l.optionalAttrs (source != null) {inherit source;}
        // l.optionalAttrs (maybeVersion != null) {version = maybeVersion;}
      );
    in
      foundDep;
    # dependency entries mapped to their original dependency
    entryToDependencyAttrs = let
      makePair = entry: l.nameValuePair entry (parseDepEntryImpl entry);
      depEntries = l.flatten (l.map (dep: dep.dependencies or []) parsedDeps);
    in
      l.listToAttrs (l.map makePair (l.unique depEntries));
    parseDepEntry = entry: entryToDependencyAttrs.${entry};

    # Parses a git source, taken straight from nixpkgs.
    parseSourceImpl = src: let
      parts = l.match ''git\+([^?]+)(\?(rev|tag|branch)=(.*))?#(.*)'' src;
      type = l.elemAt parts 2; # rev, tag or branch
      value = l.elemAt parts 3;
      checkType = type: l.hasPrefix "${type}+" src;
    in
      if checkType "registry"
      then
        if src == "registry+https://github.com/rust-lang/crates.io-index"
        then {
          type = "crates-io";
          value = null;
        }
        else throw "registries other than crates.io are not supported yet"
      else if parts != null
      then {
        type = "git";
        value =
          {
            url = l.elemAt parts 0;
            sha = l.elemAt parts 4;
          }
          // (lib.optionalAttrs (type != null) {inherit type value;});
      }
      else throw "unknown or unsupported source type: ${src}";
    parsedSources = l.listToAttrs (
      l.map
      (dep: l.nameValuePair dep.source (parseSourceImpl dep.source))
      (l.filter (dep: dep ? source) parsedDeps)
    );
    parseSource = dep:
      if dep ? source
      then parsedSources.${dep.source}
      else {
        type = "path";
        value = null;
      };

    package = rec {
      toml = packageToml.value;
      name = toml.package.name;
      version = getVersion toml.package;
    };

    extractVersionFromDep = rawObj: let
      source = parseSource rawObj;
      duplicateVersions =
        l.filter
        (dep: dep.version == rawObj.version)
        depNamesToVersions.${rawObj.name};
    in
      if l.length duplicateVersions > 1 && source.type != "path"
      then rawObj.version + "$" + source.type
      else rawObj.version;
  in
    simpleTranslate2
    ({...}: {
      translatorName = "cargo-lock";
      # relative path of the project within the source tree.
      location = projectRelPath;

      # the name of the subsystem
      subsystemName = "rust";

      # Extract subsystem specific attributes.
      # The structure of this should be defined in:
      #   ./src/specifications/{subsystem}
      subsystemAttrs = {
        relPathReplacements = let
          # function to find path replacements for one package
          findReplacements = package: let
            # Extract dependencies from the Cargo.toml of the package
            tomlDeps =
              l.flatten
              (
                l.map
                (
                  target:
                    (l.attrValues (target.dependencies or {}))
                    ++ (l.attrValues (target.buildDependencies or {}))
                )
                ([package.value] ++ (l.attrValues (package.value.target or {})))
              );
            # We only need to patch path dependencies
            pathDeps = l.filter (dep: dep ? path) tomlDeps;
            # filter out path dependencies whose path are same as in workspace members.
            # this is because otherwise workspace.members paths will also get replaced in the build.
            # and there is no reason to replace these anyways since they are in the source.
            outsideDeps =
              l.filter
              (
                dep:
                  !(l.any (memberPath: dep.path == memberPath) workspaceMembers)
              )
              pathDeps;
            makeReplacement = dep: {
              name = dep.path;
              value = sanitizeRelativePath "${package.relPath}/${dep.path}";
            };
            replacements = l.listToAttrs (l.map makeReplacement outsideDeps);
            # filter out replacements which won't replace anything
            # this means that the path doesn't need to be replaced because it's
            # already in the source that we are building
            filtered =
              l.filterAttrs
              (
                n: v: ! l.pathExists (sanitizePath "${projectSource}/${v}")
              )
              replacements;
          in
            filtered;
          # find replacements for all packages we export
          allPackageReplacements =
            l.map
            (
              package: let
                pkg = package.value.package;
                replacements = findReplacements package;
              in {${pkg.name}.${getVersion pkg} = replacements;}
            )
            cargoPackages;
        in
          l.foldl' l.recursiveUpdate {} allPackageReplacements;
        gitSources = l.unique (
          l.map (src: src.value) (
            l.filter
            (src: src.type == "git")
            (l.map parseSource parsedDeps)
          )
        );
        meta = l.foldl' l.recursiveUpdate {} (
          l.map
          (
            package: let
              pkg = package.value.package;
            in {
              ${pkg.name}.${getVersion pkg} =
                {license = parseSpdxId (getLicense pkg);}
                // (
                  l.mapAttrs
                  (name: _: getPackageAttribute pkg name)
                  (
                    l.filterAttrs
                    (n: v: l.any (on: n == on) ["description" "homepage"])
                    pkg
                  )
                );
            }
          )
          cargoPackages
        );
      };

      defaultPackage = package.name;

      /*
      List the package candidates which should be exposed to the user.
      Only top-level packages should be listed here.
      Users will not be interested in all individual dependencies.
      */
      exportedPackages = let
        makePair = p: let
          pkg = p.value.package;
        in
          l.nameValuePair pkg.name (getVersion pkg);
      in
        l.listToAttrs (l.map makePair cargoPackages);

      /*
      a list of raw package objects
      If the upstream format is a deep attrset, this list should contain
      a flattened representation of all entries.
      */
      serializedRawObjects = parsedDeps;

      /*
      Define extractor functions which each extract one property from
      a given raw object.
      (Each rawObj comes from serializedRawObjects).

      Extractors can access the fields extracted by other extractors
      by accessing finalObj.
      */
      extractors = {
        name = rawObj: finalObj: rawObj.name;

        version = rawObj: finalObj: extractVersionFromDep rawObj;

        dependencies = rawObj: finalObj:
          l.map
          (dep: {
            name = dep.name;
            version = extractVersionFromDep dep;
          })
          (l.map parseDepEntry (rawObj.dependencies or []));

        sourceSpec = rawObj: finalObj: let
          source = parseSource rawObj;
          depNameVersion = {
            pname = rawObj.name;
            version = l.removeSuffix ("$" + source.type) rawObj.version;
          };
          sourceConstructors = {
            path = dependencyObject: let
              findCrate =
                l.findFirst
                (
                  crate:
                    (crate.name == dependencyObject.name)
                    && (crate.version == dependencyObject.version)
                )
                null;
              workspaceCrates =
                l.map
                (
                  pkg: {
                    inherit (pkg.value.package) name;
                    inherit (pkg) relPath;

                    version = getVersion pkg.value.package;
                  }
                )
                cargoPackages;
              workspaceCrate = findCrate workspaceCrates;
              nonWorkspaceCrate = findCrate allCrates;
              final =
                if
                  (package.name == dependencyObject.name)
                  && (package.version == dependencyObject.version)
                then {
                  type = "path";
                  path = projectRelPath;
                  rootName = null;
                  rootVersion = null;
                }
                else if workspaceCrate != null
                then {
                  type = "path";
                  path = workspaceCrate.relPath;
                  rootName = package.name;
                  rootVersion = package.version;
                }
                else if nonWorkspaceCrate != null
                then {
                  type = "path";
                  path = nonWorkspaceCrate.relPath;
                  rootName = null;
                  rootVersion = null;
                }
                else throw "could not find crate '${dependencyObject.name}-${dependencyObject.version}'";
            in
              final;

            git = dependencyObject: let
              parsed = source.value;
              maybeRef =
                if parsed.type or null == "branch"
                then {ref = "refs/heads/${parsed.value}";}
                else if parsed.type or null == "tag"
                then {ref = "refs/tags/${parsed.value}";}
                else {};
            in
              maybeRef
              // {
                type = "git";
                url = parsed.url;
                rev = parsed.sha;
              };

            crates-io = dependencyObject:
              depNameVersion
              // {
                type = "crates-io";
                hash = dependencyObject.checksum or (getChecksum dependencyObject);
              };
          };
        in
          sourceConstructors."${source.type}" rawObj;
      };
    });
in
  translate
