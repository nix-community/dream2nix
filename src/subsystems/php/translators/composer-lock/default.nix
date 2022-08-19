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
      url = "https://code.castopod.org/adaures/castopod/-/archive/v1.0.0-alpha.80/castopod-v1.0.0-alpha.80.tar.gz";
      sha256 = "sha256:0lv75pxzhs6q9w22czbgbnc48n6zhaajw9bag2sscaqnvfvfhcsf";
    })
  ];

  /*
  Allow dream2nix to detect if a given directory contains a project
  which can be translated with this translator.
  Usually this can be done by checking for the existence of specific
  file names or file endings.

  Alternatively a fully featured discoverer can be implemented under
  `src/subsystems/{subsystem}/discoverers`.
  This is recommended if more complex project structures need to be
  discovered like, for example, workspace projects spanning over multiple
  sub-directories

  If a fully featured discoverer exists, do not define `discoverProject`.
  */
  discoverProject = tree:
    (l.pathExists "${tree.fullPath}/composer.json")
    && (l.pathExists "${tree.fullPath}/composer.lock");

  # translate from a given source and a project specification to a dream-lock.
  translate = {
    translatorName,
    utils,
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
    ...
  } @ args: let
    # get the root source and project source
    rootSource = tree.fullPath;
    projectSource = "${tree.fullPath}/${project.relPath}";
    projectTree = tree.getNodeFromPath project.relPath;

    composerJson = (projectTree.getNodeFromPath "composer.json").jsonContent;
    composerLock = (projectTree.getNodeFromPath "composer.lock").jsonContent;

    # toplevel php semver
    phpSemver = composerJson.require."php";

    # all the requires (dependencies)
    allRequires = composerLock.packages;

    # get the requierements without php version pin & without php extensions
    cleanRequire = requires:
      l.filterAttrs
      (name: _: (name != "php") && !(l.strings.hasPrefix "ext-" name))
      requires;

    # composer.lock uses a less strict semver interpretation
    # ~1.2 -> >=1.2 <2.0.0 (instead of >=1.2.0 <1.3.0)
    # this is identical with ^1.2 in the semver standard
    satisfiesSemver = version: constraint: let
      minorTilde = l.match "^[~]([[:d:]]+[.][[:d:]]+)$" constraint;
      cleanConstraint =
        if minorTilde != null && l.length minorTilde >= 0
        then "^${l.head minorTilde}"
        else constraint;
      cleanVersion = l.removePrefix "v" version;
    in
      utils.satisfiesSemver cleanVersion cleanConstraint;

    # resolve semvers into exact versions
    pinRequires = dep: let
      pin = name: semver:
        (l.head
          (l.filter (dep: satisfiesSemver dep.version semver)
            (l.filter (dep: dep.name == name)
              allRequires)))
        .version;
      pinnedRequires =
        if "require" ? dep
        then l.mapAttrs pin dep.require
        else {};
    in
      dep // {require = pinnedRequires;};
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
        inherit satisfiesSemver phpSemver;
      };

      # name of the default package
      defaultPackage = composerJson.name;

      /*
      List the package candidates which should be exposed to the user.
      Only top-level packages should be listed here.
      Users will not be interested in all individual dependencies.
      */
      exportedPackages = {
        "${defaultPackage}" = composerJson.version;
      };

      /*
      a list of raw package objects
      If the upstream format is a deep attrset, this list should contain
      a flattened representation of all entries.
      */
      serializedRawObjects =
        (map pinRequires composerLock.packages)
        ++ [
          # Add the top-level package, this is not written in composer.lock
          {
            name = defaultPackage;
            version = exportedPackages."${defaultPackage}";
            source = {
              type = "path";
              path = projectSource;
            };
            require = (pinRequires composerJson).require;
          }
        ];

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
          (cleanRequire rawObj.require);

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
        # {
        #   name = "foo2";
        #   version = "1.0";
        #   dependencies = [
        #     {
        #       name = "bar2";
        #       version = "1.1";
        #     }
        #   ];
        #   sourceSpec = {
        #     type = "git";
        #     url = "https://...";
        #     rev = "...";
        #   };
        # }
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
  };
}
