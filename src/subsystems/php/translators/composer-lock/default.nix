{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;
in {
  type = "pure";

  /*
  Automatically generate unit tests for this translator using project sources
  from the specified list.

  !!! Your first action should be adding a project here. This will simplify
  your work because you will be able to use `nix run .#tests-unit` to
  test your implementation for correctness.
  */
  generateUnitTestsForProjects = [
    (builtins.fetchTarball {
      url = "https://github.com/tinybeachthor/dream2nix-php-composer-lock/archive/refs/tags/complex.tar.gz";
      sha256 = "sha256:1xa5paafhwv4bcn2jsmbp1v2afh729r2h153g871zxdmsxsgwrn1";
    })
  ];

  # translate from a given source and a project specification to a dream-lock.
  translate = {
    translatorName,
    callPackageDream,
    ...
  }: {
    /*
    A list of projects returned by `discoverProjects`
    Example:
      [
        {
          "dreamLockPath": "packages/optimism/dream-lock.json",
          "name": "optimism",
          "relPath": "",
          "subsystem": "nodejs",
          "subsystemInfo": {
            "workspaces": [
              "packages/common-ts",
              "packages/contracts",
              "packages/core-utils",
            ]
          },
          "translator": "yarn-lock",
          "translators": [
            "yarn-lock",
            "package-json"
          ]
        }
      ]
    */
    project,
    /*
    Entire source tree represented as deep attribute set.
    (produced by `prepareSourceTree`)

    This has the advantage that files will only be read once, even when
    accessed multiple times or by multiple translators.

    Example:
      {
        files = {
          "package.json" = {
            relPath = "package.json"
            fullPath = "${source}/package.json"
            content = ;
            jsonContent = ;
            tomlContent = ;
          }
        };

        directories = {
          "packages" = {
            relPath = "packages";
            fullPath = "${source}/packages";
            files = {

            };
            directories = {

            };
          };
        };

        # returns the tree object of the given sub-path
        getNodeFromPath = path: ...
      }
    */
    tree,
    # arguments defined in `extraArgs` (see below) specified by user
    noDev,
    ...
  } @ args: let
    # get the root source and project source
    rootSource = tree.fullPath;
    projectSource = "${tree.fullPath}/${project.relPath}";
    projectTree = tree.getNodeFromPath project.relPath;

    composerJson = (projectTree.getNodeFromPath "composer.json").jsonContent;
    composerLock = (projectTree.getNodeFromPath "composer.lock").jsonContent;

    inherit
      (callPackageDream ../../utils.nix {})
      satisfiesSemver
      multiSatisfiesSemver
      ;

    # all the packages
    packages =
      composerLock.packages
      ++ (
        if noDev
        then []
        else composerLock.packages-dev
      );

    # packages with replacements applied
    resolvedPackages = let
      getProvide = pkg: (pkg.provide or {});
      getReplace = pkg: let
        resolveVersion = _: version:
          if version == "self.version"
          then pkg.version
          else version;
      in
        l.mapAttrs resolveVersion (pkg.replace or {});
      provide = pkg: dep: let
        requirements = getDependencies pkg;
        providements = getProvide dep;
        cleanRequirements =
          l.filterAttrs (
            name: semver:
              !((providements ? "${name}")
                && (multiSatisfiesSemver providements."${name}" semver))
          )
          requirements;
      in
        pkg
        // {
          require =
            cleanRequirements
            // (
              if requirements != cleanRequirements
              then {"${dep.name}" = "${dep.version}";}
              else {}
            );
        };
      replace = pkg: dep: let
        requirements = getDependencies pkg;
        replacements = getReplace dep;
        cleanRequirements =
          l.filterAttrs (
            name: semver:
              !((replacements ? "${name}")
                && (satisfiesSemver replacements."${name}" semver))
          )
          requirements;
      in
        pkg
        // {
          require =
            cleanRequirements
            // (
              if requirements != cleanRequirements
              then {"${dep.name}" = "${dep.version}";}
              else {}
            );
        };
      doReplace = pkg: l.foldl replace pkg packages;
      doProvide = pkg: l.foldl provide pkg packages;
      dropMissing = pkgs: let
        doDropMissing = pkg:
          pkg
          // {
            require =
              l.filterAttrs
              (name: semver: l.any (pkg: (pkg.name == name) && (satisfiesSemver pkg.version semver)) pkgs)
              (getDependencies pkg);
          };
      in
        map doDropMissing pkgs;
      resolve = pkg: (doProvide (doReplace pkg));
    in
      dropMissing (map resolve packages);

    # toplevel php semver
    phpSemver = composerJson.require."php" or "*";
    # all the php extensions
    phpExtensions = let
      all = map (pkg: l.attrsets.attrNames (getDependencies pkg)) resolvedPackages;
      flat = l.lists.flatten all;
      extensions = l.filter (l.strings.hasPrefix "ext-") flat;
    in
      map (l.strings.removePrefix "ext-") (l.lists.unique extensions);

    # get dependencies
    getDependencies = pkg:
      l.mapAttrs
      (name: version:
        if version == "self.version"
        then pkg.version
        else version)
      (pkg.require or {});

    # resolve semvers into exact versions
    pinPackages = pkgs: let
      clean = requires:
        l.filterAttrs
        (name: _:
          (l.all (x: name != x) ["php" "composer/composer" "composer-runtime-api"])
          && !(l.strings.hasPrefix "ext-" name))
        requires;
      doPin = name: semver:
        (l.head
          (l.filter (dep: satisfiesSemver dep.version semver)
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
  in
    dlib.simpleTranslate2.translate
    ({objectsByKey, ...}: rec {
      inherit translatorName;

      # relative path of the project within the source tree.
      location = project.relPath;

      # the name of the subsystem
      subsystemName = "php";

      # Extract subsystem specific attributes.
      # The structure of this should be defined in:
      #   ./src/specifications/{subsystem}
      subsystemAttrs = {
        inherit phpSemver phpExtensions;
      };

      # name of the default package
      defaultPackage = project.name;

      /*
      List the package candidates which should be exposed to the user.
      Only top-level packages should be listed here.
      Users will not be interested in all individual dependencies.
      */
      exportedPackages = {
        "${defaultPackage}" = composerJson.version or "unknown";
      };

      /*
      a list of raw package objects
      If the upstream format is a deep attrset, this list should contain
      a flattened representation of all entries.
      */
      serializedRawObjects = pinPackages (
        [
          # Add the top-level package, this is not written in composer.lock
          {
            name = defaultPackage;
            version = exportedPackages."${defaultPackage}";
            source = {
              type = "path";
              path = projectSource;
            };
            require =
              (
                if noDev
                then {}
                else composerJson.require-dev or {}
              )
              // composerJson.require;
          }
        ]
        ++ resolvedPackages
      );

      /*
      Define extractor functions which each extract one property from
      a given raw object.
      (Each rawObj comes from serializedRawObjects).

      Extractors can access the fields extracted by other extractors
      by accessing finalObj.
      */
      extractors = {
        name = rawObj: finalObj:
          rawObj.name;

        version = rawObj: finalObj:
          rawObj.version;

        dependencies = rawObj: finalObj:
          l.attrsets.mapAttrsToList
          (name: version: {inherit name version;})
          (getDependencies rawObj);

        sourceSpec = rawObj: finalObj:
          if rawObj.source.type == "path"
          then {
            inherit (rawObj.source) type path;
          }
          else {
            inherit (rawObj.source) type url;
            rev = rawObj.source.reference;
          };
      };

      /*
      Optionally define extra extractors which will be used to key all
      final objects, so objects can be accessed via:
      `objectsByKey.${keyName}.${value}`
      */
      keys = {
      };

      /*
      Optionally add extra objects (list of `finalObj`) to be added to
      the dream-lock.
      */
      extraObjects = [
      ];
    });

  # If the translator requires additional arguments, specify them here.
  # Users will be able to set these arguments via `settings`.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  # Flags are false by default.
  extraArgs = {
    noDev = {
      description = "Exclude development dependencies";
      type = "flag";
    };
  };
}
