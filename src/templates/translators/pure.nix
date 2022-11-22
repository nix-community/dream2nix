/*
This is an example for a pure translator which translates niv's sources.json
  to a dream2nix dream-lock(.json).

Example sources.json: https://github.com/nmattia/niv/blob/351d8bc316bf901a81885bab5f52687ec8ccab6e/nix/sources.json
*/
{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;
in {
  type = "pure";

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
  /*
  TODO: change this function to identify projects that can be translated
   by the current translator.
  */
  # checks if the path
    l.pathExists "${tree.fullPath}/nix/sources.json";

  # translate from a given source and a project specification to a dream-lock.
  translate = {
    /*
    A list of projects returned by `discoverProjects`
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
        }
      }
    */
    project,
    /*
    Entire source tree represented as nested attribute set.
    (produced by `dlib.prepareSourceTree`)

    This has the advantage that files will only be read/parsed once, even
    when accessed multiple times or by multiple translators.

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
              ...
            };
            directories = {
              ...
            };
          };
        };

        # returns the tree object of the given sub-path
        getNodeFromPath = path: ...
      }
    */
    tree,
    /*
    arguments defined in `extraArgs` specified by user
    (see definition for `extraArgs` near the bottom of this file)
    */
    noDev,
    theAnswer,
    ...
  }: let
    # get the root source and project source
    rootSource = tree.fullPath;
    projectSource = "${tree.fullPath}/${project.relPath}";
    projectTree = tree.getNodeFromPath project.relPath;

    # use dream2nix' source tree abstraction to access json content of files
    sourcesJson =
      (projectTree.getNodeFromPath "nix/sources.json").jsonContent;

    /*

    Define the name and version of the top-level package.
    If there are multiple top-level packages, just pick any of them.
    Dream2nix requires one package to be the default package.
    TODO: change this. In the case of niv, we just pick some static values
      here because there isn't really a concept of a package in niv.
      (Later we just fetch the dependencies and merge them into one output)
    */
    defaultPackageName = "my-niv-dependencies";
    defaultPackageVersion = "unknown-version";
  in
    # see example in src/specifications/dream-lock-example.json
    {
      /*
      Tell dream2nix that this is the human-readable (decompressed)
       representation of the dream-lock.
      */
      decompressed = true;


      # generic fields
      _generic = {
        # TODO: specify the default package name
        defaultPackage = defaultPackageName;

        # the location of the package within the source tree
        location = project.relPath;

        # TODO: specify a list of exported packages and their versions
        packages = {
          my-niv-dependencies = "unknown-version";
        };

        # TODO: this must be equivalent to the subsystem name
        subsystem = "my-subsystem";
      };

      /*
      Store subsystem specific data.
      This is needed if the subsystem requires extra metadata to be stored.
      This will be a free-form field as long as no jsonschema exists for
       this subsystem.
      TODO: create a jsonschema for the current subsystem under
       /src/specifications/{subsystem}/dream-lock-schema.json
      */
      _subsystem = {
        example-key = "example-value";
      };

      /*
      List dependency edges that need to be removed in order to prevent
       infinite recursions in the nix evaluator.
      Usually this can be ommitted.
      */
      cyclicDependencies = null;

      /*
      Define the dependency graph.
      This can be set to `null`, in which case dream2nix assumes that:
       - all sources listed in `sources` represent one dependency
       - all dependencies are direct dependenceis of the `defaultPackage`
      Example:
        # foo-1.2.3 depends on bar-2.3.4 and baz-3.4.5
        {
          foo."1.2.3" = [
            {name = "bar"; version = "2.3.4"}
            {name = "baz"; version = "3.4.5"}
          ]
          ...
        }
      */
      dependencies = {
        ${defaultPackageName}.${defaultPackageVersion} =
          l.mapAttrsToList
          (
            sourceName: source: {
              name = sourceName;
              version = source.rev or "unknown-version";
            }
          )
          sourcesJson;
      };

      /*
      Define the sources for all dependencies including their checksums.
      This allows dream2nix to fetch all sources reproducibly.
      Each dependency specified in `dependencies` must have a corresponding
       entry in `sources` which describes how the source can be fetched.
      Check the `fetchers` section in the docs to see what fetchers are
       supported and which arguments they require.
      Example:
        {
          foo."1.2.3" = {
            type = "http";
            url = "https://foo.com/tarball.tar.gz";
            hash = "sha256:000000000000000000000000000000000000000";
          };
          bar."2.3.4" = {
            ...
          }
          ...
        }
      */
      sources =
        l.mapAttrs
        (sourceName: source: {
          ${source.rev or "unknown-version"} = {
            type = "archive";
            url = source.url;
            hash = "sha256:${source.sha256}";
          };
        })
        sourcesJson;
    };

  # If the translator requires additional arguments, specify them here.
  # Users will be able to set these arguments via `settings`.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  # Flags are false by default.
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
