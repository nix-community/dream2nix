{
  lib,
  nodejsUtils,
  dreamLockUtils,
  simpleTranslate,
  ...
}: let
  l = lib // builtins;
  # translate from a given source and a project specification to a dream-lock.
  translate = {
    projectName,
    projectRelPath,
    composerLock,
    composerJson,
    tree,
    noDev,
    ...
  } @ args: let
    inherit
      (import ./semver.nix {inherit lib;})
      satisfies
      multiSatisfies
      ;

    # get the root source and project source
    rootSource = tree.fullPath;
    projectSource = "${tree.fullPath}/${projectRelPath}";
    projectTree = tree.getNodeFromPath projectRelPath;

    composerJson = (projectTree.getNodeFromPath "composer.json").jsonContent;
    composerLock = (projectTree.getNodeFromPath "composer.lock").jsonContent;

    # toplevel php semver
    phpSemver = composerJson.require."php" or "*";
    # all the php extensions
    phpExtensions = let
      allDepNames = l.flatten (map (x: l.attrNames (getRequire x)) packages);
      extensions = l.unique (l.filter (l.hasPrefix "ext-") allDepNames);
    in
      map (l.removePrefix "ext-") extensions;

    composerPluginApiSemver = l.listToAttrs (l.flatten (map
      (
        pkg: let
          requires = getRequire pkg;
        in
          l.optional (requires ? "composer-plugin-api")
          {
            name = "${pkg.name}@${pkg.version}";
            value = requires."composer-plugin-api";
          }
      )
      packages));

    # get cleaned pkg attributes
    getRequire = pkg:
      l.mapAttrs
      (_: version: resolvePkgVersion pkg version)
      (pkg.require or {});
    getProvide = pkg:
      l.mapAttrs
      (_: version: resolvePkgVersion pkg version)
      (pkg.provide or {});
    getReplace = pkg:
      l.mapAttrs
      (_: version: resolvePkgVersion pkg version)
      (pkg.replace or {});

    resolvePkgVersion = pkg: version:
      if version == "self.version"
      then pkg.version
      else version;

    # project package
    toplevelPackage = {
      name = projectName;
      version = composerJson.version or "unknown";
      source = {
        type = "path";
        path = rootSource;
      };
      require =
        (l.optionalAttrs (!noDev) (composerJson.require-dev or {}))
        // (composerJson.require or {});
    };
    getPath = dependencyObject:
      lib.removePrefix "file:" dependencyObject.version;
    # all the packages
    packages =
      # Add the top-level package, this is not written in composer.lock
      [toplevelPackage]
      ++ composerLock.packages
      ++ (l.optionals (!noDev) (composerLock.packages-dev or []));
    # packages with replace/provide applied
    resolvedPackages = let
      apply = pkg: dep: candidates: let
        original = getRequire pkg;
        applied =
          l.filterAttrs
          (
            name: semver:
              !((candidates ? "${name}") && (multiSatisfies candidates."${name}" semver))
          )
          original;
      in
        pkg
        // {
          require =
            applied
            // (
              l.optionalAttrs
              (applied != original)
              {"${dep.name}" = "${dep.version}";}
            );
        };
      dropMissing = pkgs: let
        doDropMissing = pkg:
          pkg
          // {
            require =
              l.filterAttrs
              (name: semver: l.any (pkg: (pkg.name == name) && (satisfies pkg.version semver)) pkgs)
              (getRequire pkg);
          };
      in
        map doDropMissing pkgs;
      doReplace = pkg:
        l.foldl
        (pkg: dep: apply pkg dep (getProvide dep))
        pkg
        packages;
      doProvide = pkg:
        l.foldl
        (pkg: dep: apply pkg dep (getReplace dep))
        pkg
        packages;
    in
      dropMissing (map (pkg: (doProvide (doReplace pkg))) packages);

    # resolve semvers into exact versions
    pinPackages = pkgs: let
      clean = requires:
        l.filterAttrs
        (name: _:
          !(l.elem name ["php" "composer-plugin-api" "composer-runtime-api"])
          && !(l.strings.hasPrefix "ext-" name))
        requires;
      doPin = name: semver:
        (l.head
          (l.filter (dep: satisfies dep.version semver)
            (l.filter (dep: dep.name == name)
              resolvedPackages)))
        .version;
      doPins = pkg:
        pkg
        // {
          require = l.mapAttrs doPin (clean pkg.require);
        };
    in
      map doPins pkgs;
    createMissingSource = name: version: {
      type = "http";
      url = "https://registry.npmjs.org/${name}/-/${name}-${version}.tgz";
    };
    inputData =
      builtins.listToAttrs
      (map
        (k: {
          name = k.name;
          value = k // {version = k.version;};
        })
        (pinPackages resolvedPackages));
    serializePackages = inputData: let
      serialize = inputData:
        lib.mapAttrsToList # returns list of lists
        
        (pname: pdata:
          [
            (pdata
              // {
                inherit pname;
                depsExact =
                  lib.filter
                  (req: (! (pdata.require."${req.name}".bundled or false)))
                  pdata.depsExact or [];
              })
          ]
          ++ (lib.optionals (pdata ? dependencies)
            (lib.flatten
              (serialize
                (lib.filterAttrs
                  (pname: data: ! data.bundled or false)
                  pdata.dependencies)))))
        inputData;
    in
      lib.filter
      (pdata:
        ! noDev || ! (pdata.dev or false))
      (lib.flatten (serialize inputData));
  in
    simpleTranslate
    ({...}: rec {
      translatorName = projectName;

      location = projectRelPath;

      subsystemName = "php";

      subsystemAttrs = {
        inherit noDev;
        inherit phpSemver phpExtensions;
        inherit composerPluginApiSemver;
      };

      getSourceType = dependencyObject:
        if false
        then "git"
        else if
          (lib.hasPrefix "file:" dependencyObject.version)
          || (
            (! lib.hasPrefix "https://" dependencyObject.version)
            && (! dependencyObject ? resolved)
          )
        then "path"
        else "http";

      defaultPackage = toplevelPackage.name;

      packages = {
        "${defaultPackage}" = toplevelPackage.version;
      };

      mainPackageDependencies =
        lib.mapAttrsToList
        (pname: pdata: {
          name = pname;
          version = getVersion pdata;
        })
        (lib.filterAttrs
          (pname: pdata: ! (pdata.dev or false) || ! noDev)
          packages);

      inherit inputData;

      getName = dependencyObject: dependencyObject.name;
      getVersion = resolvePkgVersion;

      inherit serializePackages;

      sourceConstructors = {
        git = dependencyObject:
          nodejsUtils.parseGitUrl dependencyObject.version;

        http = dependencyObject:
          if lib.hasPrefix "https://" dependencyObject.version
          then rec {
            version = getVersion dependencyObject;
            url = dependencyObject.version;
            hash = dependencyObject.integrity;
          }
          else if dependencyObject.resolved == false
          then
            (createMissingSource
              (getName dependencyObject)
              (getVersion dependencyObject))
            // {
              hash = dependencyObject.integrity;
            }
          else rec {
            url = dependencyObject.resolved;
            hash = dependencyObject.integrity;
          };

        path = dependencyObject:
        # in case of an entry with missing resolved field
          if ! lib.hasPrefix "file:" dependencyObject.version
          then
            dreamLockUtils.mkPathSource
            {
              path = let
                module = l.elemAt (l.splitString "/" dependencyObject.pname) 0;
              in "node_modules/${module}";
              rootName = projectName;
              rootVersion = toplevelPackage.version;
            }
          # in case of a "file:" entry
          else
            dreamLockUtils.mkPathSource {
              path = getPath dependencyObject;
              rootName = projectName;
              rootVersion = toplevelPackage.version;
            };
      };

      getDependencies = dependencyObject:
        dependencyObject.require;
    });
in
  translate
