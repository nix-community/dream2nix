{
  config,
  lib,
  dream2nix,
  packageSets,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.pip = {
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
    requirementsFiles = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        list of requirements.txt files
      '';
    };

    buildExtras = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        list of python "extras" to build with. This can be a subset of the
        extras in your lock file.
      '';
    };

    nativeBuildInputs = l.mkOption {
      type = t.listOf t.package;
      default = [];
      description = ''
        list of native packages to include during metadata generation
      '';
    };

    drvs = l.mkOption {
      type = t.lazyAttrsOf (t.submoduleWith {
        modules = [dream2nix.modules.drv-parts.core];
        specialArgs = {inherit packageSets dream2nix;};
      });
      description = "drv-parts modules that define python dependencies";
    };
  };
}
