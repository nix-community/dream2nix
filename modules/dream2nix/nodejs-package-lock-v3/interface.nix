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

  derivationType = t.oneOf [t.str t.path t.package];

  # A stricter submodule type that prevents derivations from being
  # detected as modules by accident. (derivations are attrs as well as modules)
  drvPart = let
    type = t.submoduleWith {
      modules = [dream2nix.modules.dream2nix.core];
      inherit specialArgs;
    };
  in
    type
    // {
      # Ensure that derivations are never detected as modules by accident.
      check = val: type.check val && (val.type or null != "derivation");
    };

  drvPartOrPackage = t.either derivationType drvPart;

  optPackage = l.mkOption {
    type = drvPartOrPackage;
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

    /*

    type: pdefs.${name}.${version} :: {
      
      // Pointing to the source of the package.
      // in most cases this is a tarball (tar.gz) which needs to be unpacked by e.g. unpackPhase
      source :: Derivation | Path

      // all dependency entries of that package.
      // each dependency is guaranteed to have its own entry in 'pdef'
      // A package without dependencies has `dependencies = {}` (Empty set)
      dependencies = {
        ${name} = {
          dev = boolean;
          version :: string;
        }
      }
    }
   */ 
    pdefs = {
      type = t.attrsOf (t.attrsOf (t.submodule {
        options.dependencies = l.mkOption {
          type = dependenciesType;
        };
        options.source = optPackage;
      }));
    };
  };
}
