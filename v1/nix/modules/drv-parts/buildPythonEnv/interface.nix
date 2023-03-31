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
    pypiSnapshotDate = l.mkOption {
      type = t.str;
      description = ''
        maximum release date for packages
        Choose any date from the past.
      '';
      example = "2023-01-01";
    };
    pipFlags = l.mkOption {
      type = t.listOf t.str;
      description = ''
        list of flags for pip install
      '';
      default = [];
    };
    requirementsList = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        list of strings of requirements.txt entries
      '';
    };
    requirementsFiles = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        list of requirements.txt files
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
  };
}
