{
  dlib,
  lib,
  name,
  pkgs,
  inputs,
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
      url = "https://github.com/leungbk/ghcid/tarball/1a1aa2f3ee409a0044340f2759d21b64b56b0010";
      sha256 = "sha256:1mp33xkyyb4jqqriczai80sqwlrjcwd94l7bv709ngwjqy56h2n9";
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
  # Example
  # Returns true if given directory contains a file ending with cabal.project.freeze
    l.any
    (filename: l.hasSuffix "cabal.project.freeze" filename)
    (l.attrNames tree.files);

  # translate from a given source and a project specification to a dream-lock.
  translate = {
    /*
    A project returned by `discoverProjects`
    Example:

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
    ghcVersion,
    defaultPackageName,
    defaultPackageVersion,
    ...
  } @ args: let
    # get the root source and project source
    rootSource = tree.fullPath;
    projectSource = "${tree.fullPath}/${project.relPath}";
    projectTree = tree.getNodeFromPath project.relPath;

    parsedCabalFreeze = l.pipe projectTree.files [
      l.attrNames
      (
        l.findFirst (l.hasSuffix "cabal.project.freeze")
        (throw "No cabal.project.freeze file in the tree")
      )
      projectTree.getNodeFromPath
      (l.attrByPath ["fullPath"] "")
      (import ./parser.nix {inherit dlib lib;})
    ];

    haskellUtils = import ../utils.nix {inherit inputs lib pkgs;};

    hiddenPackages = haskellUtils.ghcVersionToHiddenPackages."${ghcVersion}";

    serializedRawObjects = l.filter ({name, ...}: (! hiddenPackages ? ${name})) parsedCabalFreeze.packagesAndVersionsList;

    cabalData =
      haskellUtils.batchFindJsonFromCabalCandidates
      serializedRawObjects;

    cabalFreezeFlags = l.pipe serializedRawObjects [
      (l.map ({
        name,
        version,
      }:
        l.nameValuePair name {"${version}" = parsedCabalFreeze.cabalFlags."${name}" or [];}))
      (flagsAlist: [(l.nameValuePair defaultPackageName {"${defaultPackageVersion}" = parsedCabalFreeze.cabalFlags."${defaultPackageName}" or [];})] ++ flagsAlist)
      l.listToAttrs
    ];
  in
    dlib.simpleTranslate2.translate
    ({objectsByKey, ...}: rec {
      translatorName = name;

      # relative path of the project within the source tree.
      location = project.relPath;

      # the name of the subsystem
      subsystemName = "haskell";

      # Extract subsystem specific attributes.
      # The structure of this should be defined in:
      #   ./src/specifications/{subsystem}
      subsystemAttrs = {
        cabalFlags = cabalFreezeFlags;

        compiler = {
          name = "ghc";
          version = ghcVersion;
        };
      };

      # name of the default package
      defaultPackage = defaultPackageName;

      /*
      List the package candidates which should be exposed to the user.
      Only top-level packages should be listed here.
      Users will not be interested in all individual dependencies.
      */
      exportedPackages = {
        "${defaultPackage}" = defaultPackageVersion;
      };

      /*
      a list of raw package objects
      If the upstream format is a deep attrset, this list should contain
      a flattened representation of all entries.
      */
      inherit serializedRawObjects;

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
          l.pipe cabalData
          [
            (haskellUtils.getDependencyNames finalObj)
            (l.filter (name:
              # Keep only .cabal dependencies present in the freeze file
              (objectsByKey.name ? ${name})))
            (l.map
              (depName: {
                name = depName;
                version = objectsByKey.name.${depName}.version;
              }))
          ];

        sourceSpec = rawObj: finalObj:
        # example
        {
          type = "http";
          url = haskellUtils.getHackageUrl finalObj;
          hash = "sha256:${haskellUtils.findSha256FromCabalCandidate finalObj.name finalObj.version}";
        };
      };

      /*
      Optionally define extra extractors which will be used to key all
      final objects, so objects can be accessed via:
      `objectsByKey.${keyName}.${value}`
      */
      keys = {
        name = rawObj: finalObj:
          finalObj.name;
      };

      /*
      Optionally add extra objects (list of `finalObj`) to be added to
      the dream-lock.
      */
      # TODO: support multiple top-level packages; this requires parsing the "packages" heading in cabal.project
      extraObjects = [
        {
          name = defaultPackage;
          version = exportedPackages."${defaultPackage}";
          # XXX: some of these are transitive dependencies, but
          # including only direct deps requires that we either parse
          # the Cabal file or use a potentially outdated one from
          # all-cabal-json
          dependencies = serializedRawObjects;
          sourceSpec = {
            type = "path";
            path = projectTree.fullPath;
          };
        }
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
    ghcVersion = {
      description = "GHC version";
      default = pkgs.ghc.version;
      examples = ["9.0.2" "9.4.1"];
      type = "argument";
    };

    defaultPackageName = {
      description = "Name of default package";
      default = "main";
      examples = ["main" "default"];
      type = "argument";
    };

    defaultPackageVersion = {
      description = "Version of default package";
      default = "unknown";
      examples = ["unknown" "1.2.0"];
      type = "argument";
    };
  };
}
