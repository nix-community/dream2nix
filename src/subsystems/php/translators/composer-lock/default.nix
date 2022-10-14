{
  name,
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
    inherit
      (import ../../semver.nix {inherit lib;})
      satisfies
      multiSatisfies
      ;

    # get the root source and project source
    rootSource = tree.fullPath;
    projectSource = "${tree.fullPath}/${project.relPath}";
    projectTree = tree.getNodeFromPath project.relPath;

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
      name = project.name;
      version = composerJson.version or "unknown";
      source = {
        type = "path";
        path = rootSource;
      };
      require =
        (l.optionalAttrs (!noDev) (composerJson.require-dev or {}))
        // (composerJson.require or {});
    };
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
          l.filterAttrs (
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
  in
    dlib.simpleTranslate2.translate
    ({objectsByKey, ...}: rec {
      translatorName = name;

      # relative path of the project within the source tree.
      location = project.relPath;

      # the name of the subsystem
      subsystemName = "php";

      # Extract subsystem specific attributes.
      # The structure of this should be defined in:
      #   ./src/specifications/{subsystem}
      subsystemAttrs = {
        inherit noDev;
        inherit phpSemver phpExtensions;
        inherit composerPluginApiSemver;
      };

      # name of the default package
      defaultPackage = toplevelPackage.name;

      /*
      List the package candidates which should be exposed to the user.
      Only top-level packages should be listed here.
      Users will not be interested in all individual dependencies.
      */
      exportedPackages = {
        "${defaultPackage}" = toplevelPackage.version;
      };

      /*
      a list of raw package objects
      If the upstream format is a deep attrset, this list should contain
      a flattened representation of all entries.
      */
      serializedRawObjects = pinPackages resolvedPackages;

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
          (getRequire rawObj);

        sourceSpec = rawObj: finalObj:
          if rawObj ? "source" && rawObj.source.type == "path"
          then {
            inherit (rawObj.source) type path;
            rootName = finalObj.name;
            rootVersion = finalObj.version;
          }
          else if rawObj ? "source" && rawObj.source.type == "git"
          then {
            inherit (rawObj.source) type url;
            rev = rawObj.source.reference;
            submodules = false;
          }
          else if rawObj ? "dist" && rawObj.dist.type == "path"
          then {
            inherit (rawObj.dist) type;
            path = rawObj.dist.url;
            rootName = finalObj.name;
            rootVersion = finalObj.version;
          }
          else
            l.abort ''
              Cannot find source for ${finalObj.name}@${finalObj.version},
              rawObj: ${l.toJSON rawObj}
            '';
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
