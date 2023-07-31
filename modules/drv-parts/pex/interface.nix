# pex
# ---
#
#
{
  config,
  lib,
  drv-parts,
  dream2nix,
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
  options.pex = {
    pipVersion = l.mkOption {
      type = t.str;
      description = ''
        pip version to use to generate the report
      '';
      default = "23.1";
    };

    requirementsList = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        list of strings of requirements.txt entries
      '';
    };
    #requirementsFiles = l.mkOption {
    #  type = t.listOf t.str;
    #  default = [];
    #  description = ''
    #    list of requirements.txt files
    #  '';
    #};

    extras = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        python extras to build with, must be a subset of the extras requested when locking.
      '';
    };

    environ = l.mkOption {
      type = t.attrs;
      default = config.deps.pyproject-nix.pep508.mkEnviron config.deps.python;
      description = ''
        python environment to evaluate markers in; to decide which dependencies
        are required on which platform.
      '';
    };

    packages = l.mkOption {
      type = t.lazyAttrsOf (t.submoduleWith {
        modules = [drv-parts.modules.drv-parts.core];
        specialArgs = {inherit packageSets dream2nix;};
      });
      description = "drv-parts modules that of python packages produced";
    };

    lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
    };
  };
}
