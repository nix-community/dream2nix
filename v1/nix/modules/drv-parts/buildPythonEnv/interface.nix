{
  config,
  lib,
  drv-parts,
  packageSets,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  drvPartsTypes = import (drv-parts + /types) {
    inherit lib;
    specialArgs = {
      inherit packageSets drv-parts;
      inherit (config) name version;
    };
  };
in {
  options.buildPythonEnv = {
    pythonSources = l.mkOption {
      type = drvPartsTypes.drvPartOrPackage;
      # if module given, convert to derivation
      apply = val: val.public or val;
      description = ''
        A derivation or drv-part that outputs fetched python sources.
        Each single python source must be located in a subdirectory named after the package name.
      '';
    };

    substitutions = l.mkOption {
      type = t.lazyAttrsOf t.package;
      description = ''
        Substitute individual python packages from nixpkgs.
      '';
      default = {};
    };

    drvs = l.mkOption {
      type = t.lazyAttrsOf (t.submoduleWith {
        modules = [drv-parts.modules.drv-parts.core];
        specialArgs = {inherit packageSets;};
      });
      description = "drv-parts modules that define python dependencies";
    };

    # INTERNAL

    metadata = l.mkOption {
      type = t.lazyAttrsOf t.anything;
      # TODO submodule type definition
      description = ''
        metadata of python packages in cfg.pythonSources.
        depends on IFD and therefore should be cached
      '';
      internal = true;
      readOnly = true;
    };
  };
}
