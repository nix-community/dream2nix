# subsystemAttrs :: {
#   meta? :: {
#   }
# }
{
  config,
  options,
  lib,
  dream2nix,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
  cfg = config.nodejs-package-lock-v3;

  dreamTypes = import ../../../lib/types {
    inherit dream2nix lib specialArgs;
  };

  optPackage = l.mkOption {
    type = dreamTypes.drvPartOrPackage;
    apply = drv: drv.public or drv;
    # default = null;
  };

  # {
  #    dev = boolean;
  #    version :: string;
  # }
  depEntryType = t.submodule {
    options.dev = l.mkOption {
      type = t.bool;
      # default = false;
    };
    options.version = l.mkOption {
      type = t.str;
    };
  };

  # dependencies = {
  #     ${name} = {
  #       dev = boolean;
  #       version :: string;
  #     }
  #   }
  dependenciesType = t.attrsOf depEntryType;
in {
  options.nodejs-package-lock-v3 = l.mapAttrs (_: l.mkOption) {
    packageLockFile = {
      type = t.nullOr t.path;
      description = ''
        The package-lock.json file to use.
      '';
    };
    packageLock = {
      type = t.attrs;
      description = "The content of the package-lock.json";
    };

    # pdefs.${name}.${version} :: {
    #   // all dependency entries of that package.
    #   // each dependency is guaranteed to have its own entry in 'pdef'
    #   // A package without dependencies has `dependencies = {}` (So dependencies has a constant type)
    #   dependencies = {
    #     ${name} = {
    #       dev = boolean;
    #       version :: string;
    #     }
    #   }
    #   // Pointing to the source of the package.
    #   // in most cases this is a tarball (tar.gz) which needs to be unpacked by e.g. unpackPhase
    #   source :: Derivation | Path
    # }
    pdefs = {
      type = t.attrsOf (t.attrsOf (t.submodule {
        options.dependencies = l.mkOption {
          type = dependenciesType;
        };
        options.source = optPackage;
      }));
    };

    # packageJsonFile = {
    #   type = t.path;
    #   description = ''
    #     The package.json file to use.
    #   '';
    #   default = cfg.source + "/package.json";
    # };
    # packageJson = {
    #   type = t.attrs;
    #   description = "The content of the package.json";
    # };
    # source = {
    #   type = t.either t.path t.package;
    #   description = "Source of the package";
    #   default = config.mkDerivation.src;
    # };
    # withDevDependencies = {
    #   type = t.bool;
    #   default = true;
    #   description = ''
    #     Whether to include development dependencies.
    #     Usually it's a bad idea to disable this, as development dependencies can contain important build time dependencies.
    #   '';
    # };
    # workspaces = {
    #   type = t.listOf t.str;
    #   description = ''
    #     Workspaces to include.
    #     Defaults to the ones defined in package.json.
    #   '';
    # };
  };
}
