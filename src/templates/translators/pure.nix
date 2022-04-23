{
  dlib,
  lib,
}:

{
  translate =
    {
      translatorName,
      ...
    }:
    {
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
      theAnswer,
      ...
    }@args:
    let

      l = lib // builtins;

      # get the root source and project source
      rootSource = tree.fullPath;
      projectSource = "${tree.fullPath}/${project.relPath}";

      # parse the json / toml etc.
      projectJsonPath = "${projectSource}/project.json";
      projectJson = (tree.getNodeFromPath projectJsonPath).jsonContent;

    in

      dlib.simpleTranslate2
        ({
          objectsByKey,
          ...
        }:

        rec {

          inherit translatorName;

          # relative path of the project within the source tree.
          location = project.relPath;

          # the name of the subsystem
          subsystemName = "nodejs";

          # Extract subsystem specific attributes.
          # The structure of this should be defined in:
          #   ./src/specifications/{subsystem}
          subsystemAttrs = {theAnswer = args.theAnswer;};

          # name of the default package
          defaultPackage = "name-of-the-default-package";

          /*
            List the package candidates which should be exposed to the user.
            Only top-level packages should be listed here.
            Users will not be interested in all individual dependencies.
          */
          exportedPackages = {
            foo = "1.1.0";
            bar = "1.2.0";
          };

          /*
            a list of raw package objects
            If the upstream format is a deep attrset, this list should contain
            a flattened representation of all entries.
          */
          serializedRawObjects = [];

          /*
            Define extractor functions which each extract one property from
            a given raw object.
            (Each rawObj comes from serializedRawObjects).

            Extractors can access the fields extracted by other extractors
            by accessing finalObj.
          */
          extractors = {
            name = rawObj: finalObj:
              # example
              "foo";

            version = rawObj: finalObj:
              # example
              "1.2.3";

            dependencies = rawObj: finalObj:
              # example
              [];

            sourceSpec = rawObj: finalObj:
              # example
              {
                type = "http";
                url = "https://registry.npmjs.org/${finalObj.name}/-/${finalObj.name}-${finalObj.version}.tgz";
                hash = "sha1-4h3xCtbCBTKVvLuNq0Cwnb6ofk0=";
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
            sanitizedName = rawObj: finalObj:
              l.strings.sanitizeDerivationName rawObj.name;
          };

          /*
            Optionally add extra dependencies.
            For example, this might be required to add the top-level
            dependencies.
          */
          extraDependencies = [
            {
              # dependant
              name = "foo";
              version = "1.2.3";

              # dependencies
              dependencies = [
                {name = "bar"; version = "3.2.1";}
                {name = "baz"; version = "2.1.3";}
              ];
            }
          ];

          /*
            Optionally add extra objects (list of `finalObj`) to be added to
            the dream-lock.
          */
          extraObjects = [
            {
              name = "foo2";
              version = "1.0";
              dependencies = [
                {name = "bar2"; version = "1.1";}
              ];
              sourceSpec = {
                type = "git";
                url = "https://...";
                rev = "...";
              };
            }
          ];

        });

  # If the translator requires additional arguments, specify them here.
  # When users run the CLI, they will be asked to specify these arguments.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {

    # Example: boolean option
    # Flags always default to 'false' if not specified by the user
    noDev = {
      description = "Exclude dev dependencies";
      type = "flag";
    };

    # Example: string option
    theAnswer = {
      default = "42";
      description = "The Answer to the Ultimate Question of Life";
      examples = [
        "0"
        "1234"
      ];
      type = "argument";
    };

  };
}
