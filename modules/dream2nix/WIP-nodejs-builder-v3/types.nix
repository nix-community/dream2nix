/*
* Shared interface declarations
*/
{
  lib,
  dream2nix,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  dreamTypes = import ../../../lib/types {
    inherit dream2nix lib specialArgs;
  };

  optOptionalPackage = l.mkOption {
    type = t.nullOr dreamTypes.drvPartOrPackage;
    apply = drv: drv.public or drv;
    default = null;
  };

  depEntryType = t.submodule {
    options.dev = l.mkOption {
      type = t.bool;
      # default = false;
    };
    options.version = l.mkOption {
      type = t.str;
    };
  };
  optBins = l.mkOption {
    type = t.attrsOf t.str;
    default = {};
  };

  # dependencies = {
  #     ${name} = {
  #       dev = boolean;
  #       version :: string;
  #     }
  #   }
  dependenciesType = t.attrsOf depEntryType;

  pdefEntryOptions = {
    imports = [
      dream2nix.modules.dream2nix.public
    ];
    options.dependencies = l.mkOption {
      type = dependenciesType;
    };
    options.source = optOptionalPackage;

    options.prepared-dev = optOptionalPackage;
    options.prepared-prod = optOptionalPackage;

    options.dist = optOptionalPackage;

    options.installed = optOptionalPackage;

    options.dev = l.mkOption {
      type = t.bool;
    };

    options.info.initialState = l.mkOption {
      type = t.enum ["source" "dist"];
    };
    options.info.initialPath = l.mkOption {
      type = t.str;
    };

    # One source drv must potentially be installed in multiple other (nested) locations
    options.info.allPaths = l.mkOption {
      type = t.attrsOf t.bool;
      description = ''
        In case of conflicting versions a dependency must be installed in multiple nested locations.

        In this example: Because the root "node_modules/ansi-regex" is a different version.
        The current version must be installed privately if anyone depdends on it.

        {
          "node_modules/cliui/node_modules/ansi-regex" = true;
          "node_modules/wrap-ansi/node_modules/ansi-regex" = true;
          "node_modules/yargs/node_modules/ansi-regex" = true;
        };

        npm usually already resolved this, can be manually adjusted via this option.
      '';
    };
    options.info.fileSystem = l.mkOption {
      type = t.nullOr t.raw;
      default = null;
      description = ''
        A json serializable attribute-set.
        Holds all directories and bin symlinks realized the build script.

        Example:

        ```nix
        {
          "node_modules/tap-dot" = {
            bins = {
              "node_modules/.bin/tap-dot" = "node_modules/tap-dot/bin/dot";
            };
            source = «derivation tap-dot.drv»;
          };
          # ..
        }
        ```
      '';
    };

    /*
    "bin": {
      "esparse": "bin/esparse.js",
      "esvalidate": "bin/esvalidate.js"
    }
    */
    options.bins = optBins;
  };
in {
  inherit pdefEntryOptions;
  /*
  pdefs.${name}.${version} :: {
    // [REQUIRED] all dependency entries of that package. (Might be empty)
    // each dependency is guaranteed to have its own entry in 'pdef'
    // A package without dependencies has `dependencies = {}` (So dependencies has a constant type)
    dependencies = {
      ${name} = {
        dev = boolean;
        version :: string;
      }
    }
    // [OPTIONAL] Pointing to the source of the package.
    // SOURCE State of the package. Not every package is defined from source.
    // The rawest form of a package. The plain source code.
    // e.g. <fetch derivation> OR <filterSource derivation>
    source :: Derivation | Path

    // [OPTIONAL] PREPARED state of the packge
    // noSource = true;
    // Contains everything that is needed to build the package.
    // Does NOT contain the source code!
    // prod contains only the dependencies for runtime (needed in installed) dev contains everything needed for building (needed in dist and for the devShell).
    // could contain e.g. node_modules, .svelte-kit
    prepared-dev :: Derivation | Path
    prepared-prod :: Derivation | Path

    // [REQUIRED] BUILT State of the packge
    // src = ./.;
    // Ready to use as an dependency input for PREPARED state of another package.
    // The equivalence of npm package from npmjs.org registry.
    // In fact npm dependencies are in this state. Usually they don't even have SOURCE state.
    dist :: Derivation | Path

    // [REQUIRED] INSTALLED State of the packge
    // Ready to be used via e.g. nix-shell
    installed :: Derivation | Path

    info :: {
      initialState :: "source" | "dist"
      initialPath :: "node_modules/"
    }
  }
  */
  pdefs = {
    type = t.attrsOf (t.attrsOf (t.submodule pdefEntryOptions));
    description = ''
      Also known as 'graph'.

      Holds all information, including cyclic references.

      Use this structure to access meta information from the lockfile.
      Such as bins, path etc.

      Can be JSON serialized.
    '';
  };

  /*
  fileSystem :: {
    "node_modules/babel" :: <derivation> ;
    ${nodePath} :: Derivation
  }
  */
  # TODO: Make lazy enough. then replace info.fileSystem with this
  # fileSystem = {
  #   type = t.nullOr (t.attrsOf (t.submodule {
  #     options.source = l.mkOption {
  #       type = t.nullOr dreamTypes.drvPartOrPackage;
  #     };
  #     options.bins = optBins;
  #   }));
  #   options.bins = l.mkOption {
  #     type = t.attrsOf (t.submodule {
  #       options.name = l.mkOption {
  #         type = t.str;
  #       };
  #       options.target = l.mkOption {
  #         type = t.str;
  #       };
  #       });
  #     };
  #   }));
  # };
}
