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
  */
  generateUnitTestsForProjects = [
    (builtins.fetchTarball {
      url = "https://github.com/davhau/cabal2json/tarball/plan-json";
      sha256 = "1d0mfq8q92kikasxds20fshnwcjkm416vc2kf7l3rhmfm443snwg";
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
  # Returns true if given directory contains the dist-newstyle/cache/plan.json
    l.pathExists "${tree.fullPath}/dist-newstyle/cache/plan.json";

  # translate from a given source and a project specification to a dream-lock.
  translate = {translatorName, ...}: {
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
    ...
  } @ args: let
    # get the root source and project source
    rootSource = tree.fullPath;
    projectSource = "${tree.fullPath}/${project.relPath}";
    projectTree = tree.getNodeFromPath project.relPath;

    # parse the plan.json
    buildPlan = (projectTree.getNodeFromPath "dist-newstyle/cache/plan.json").jsonContent;

    # all objects contained in the plan.json
    rawObjectsNonBuiltin =
      l.filter
      (rawObj: rawObj.type != "pre-existing")
      buildPlan.install-plan;

    # re-structure via components
    rawObjectsByNameAndComponent =
      l.foldl
      (all: rObj: let
        name = rObj.pkg-name;
        id = rObj.id;
      in
        all
        // {
          "${name}" = all.${name} or {} // {"${id}" = rObj;};
        })
      {}
      rawObjectsNonBuiltin;

    # add field `allComponents` to each component referencing all other
    # components of that package
    rawObjectsInterlinkedComponents =
      l.listToAttrs
      (
        l.map
        (rawObj:
          l.nameValuePair
          rawObj.id
          (
            rawObj
            // {
              allComponents =
                l.attrNames (rawObjectsByNameAndComponent.${rawObj.pkg-name});
            }
          ))
        rawObjectsNonBuiltin
      );

    getCandidateForID = componentID: {
      name = rawObjectsInterlinkedComponents.${componentID}.pkg-name;
      version = rawObjectsInterlinkedComponents.${componentID}.pkg-version;
    };

    getCandidatesForIDs = componendIDs:
      l.map
      getCandidateForID
      (l.filter
        (id: rawObjectsInterlinkedComponents ? "${id}")
        componendIDs);

    # given a component ID, return all dependencies of this component and other
    # components of the same package.
    getDependenciesForID = componentID:
      l.concatMap
      (
        compID:
          getCandidatesForIDs
          (
            (rawObjectsInterlinkedComponents.${compID}.depends or [])
            ++ (rawObjectsInterlinkedComponents.${compID}.exe-depends or [])
            ++ (
              l.flatten
              (l.mapAttrsToList
                (cName: deps: deps.depends or [] ++ deps.exe-depends or [])
                rawObjectsInterlinkedComponents.${compID}.components or {})
            )
          )
      )
      rawObjectsInterlinkedComponents.${componentID}.allComponents;

    localObjects =
      l.filter
      (rawObj: rawObj.style or null == "local")
      rawObjectsNonBuiltin;
    compilerInfo = l.splitString "-" buildPlan.compiler-id;
  in
    dlib.simpleTranslate2.translate
    ({objectsByKey, ...}: rec {
      inherit translatorName;

      # relative path of the project within the source tree.
      location = project.relPath;

      # the name of the subsystem
      subsystemName = "haskell";

      # Extract subsystem specific attributes.
      # The structure of this should be defined in:
      #   ./src/specifications/{subsystem}
      subsystemAttrs = {
        cabalHashes =
          l.listToAttrs
          (
            l.map
            (
              rawObj:
                l.nameValuePair
                "${rawObj.pkg-name}#${rawObj.pkg-version}"
                rawObj.pkg-cabal-sha256
            )
            (l.filter (rawObj: rawObj ? pkg-cabal-sha256) serializedRawObjects)
          );
        compiler = {
          name = l.head compilerInfo;
          version = l.last compilerInfo;
        };
      };

      # name of the default package
      defaultPackage = (l.head localObjects).pkg-name;

      /*
      List the package candidates which should be exposed to the user.
      Only top-level packages should be listed here.
      Users will not be interested in all individual dependencies.
      */
      exportedPackages = {
        "${defaultPackage}" = (l.head localObjects).pkg-version;
      };

      /*
      a list of raw package objects
      If the upstream format is a deep attrset, this list should contain
      a flattened representation of all entries.
      */
      serializedRawObjects = l.attrValues rawObjectsInterlinkedComponents;

      /*
      Define extractor functions which each extract one property from
      a given raw object.
      (Each rawObj comes from serializedRawObjects).

      Extractors can access the fields extracted by other extractors
      by accessing finalObj.
      */
      extractors = {
        name = rawObj: finalObj:
          rawObj.pkg-name;

        version = rawObj: finalObj:
          rawObj.pkg-version;

        dependencies = rawObj: finalObj:
          getDependenciesForID rawObj.id;

        sourceSpec = rawObj: finalObj: let
          f = finalObj;
        in
          if rawObj.style == "local"
          then {
            type = "path";
            path = projectSource;
          }
          else if rawObj.pkg-src.type != "repo-tar"
          then throw "unsupported repo type ${rawObj.pkg-src.type} for package ${f.name} ${f.version}"
          else {
            type = "http";
            url = let
              uri = rawObj.pkg-src.repo.uri;
              uriSecure =
                if l.hasPrefix "http://" uri
                then "https://${(l.removePrefix "http://" uri)}"
                else uri;
            in "${uriSecure}package/${f.name}-${f.version}.tar.gz";
            hash = "sha256:${rawObj.pkg-src-sha256}";
          };
      };

      /*
      Optionally define extra extractors which will be used to key all
      final objects, so objects can be accessed via:
      `objectsByKey.${keyName}.${value}`
      */
      keys = {
        /*
        This is an example. Remove this completely or replace in case you
        need a key.
        */
        id = rawObj: finalObj:
          rawObj.id;
      };

      # TODO: implement to support multiple top-level packages
      extraObjects = [
        # {
        #   name = "foo2";
        #   version = "1.0";
        #   dependencies = [
        #     {name = "bar2"; version = "1.1";}
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
