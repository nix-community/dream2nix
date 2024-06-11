{
  lib,
  dream2nix,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
  mkSubmodule = import ../../../lib/internal/mkSubmodule.nix {inherit lib specialArgs;};
in {
  options.pip = mkSubmodule {
    imports = [
      ../overrides
      ../python-editables
    ];

    config.overrideType = {
      imports = [
        dream2nix.modules.dream2nix.buildPythonPackage
      ];
    };

    options = {
      # internal options to pass data between pip-hotfixes and pip
      targets = l.mkOption {
        type = t.raw;
        internal = true;
        description = "the targets of the lock file to build";
      };
      rootDependencies = l.mkOption {
        type = t.attrsOf t.bool;
        internal = true;
        description = "the names of the selected top-level dependencies";
      };

      # user interface
      env = l.mkOption {
        type = t.attrsOf t.str;
        default = {};
        description = ''
          environment variables exported while locking
        '';
        example = lib.literalExpression ''
          {
            PIP_FIND_LINKS = "''${config.deps.setuptools.dist}";
          }
        '';
      };

      pypiSnapshotDate = l.mkOption {
        type = t.nullOr t.str;
        description = ''
          maximum release date for packages
          Choose any date from the past.
        '';
        example = "2023-01-01";
        default = null;
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
      buildDependencies = l.mkOption {
        type = t.attrsOf t.bool;
        default = {
          cython = true;
          flit-core = true;
          flit-scm = true;
          hatch-fancy-pypi-readme = true;
          hatch-nodejs-version = true;
          hatch-vcs = true;
          hatchling = true;
          pbr = true;
          pdm-pep517 = true;
          poetry-core = true;
          poetry-dynamic-versioning = true;
          setuptools = true;
          setuptools-odoo = true;
          setuptools-scm = true;
          versioneer = true;
          wheel = true;
        };
        description = ''
          python packages to be added only as buildInputs.
          These should be somehow installable from `requirementsList` or
          `requirementsFiles` too; listing them here doesn't do that automatically.
        '';
        example = lib.literalExpression ''
          {
            setuptools-scm = false; # To disable the default
            easy_install = true; # To select easy_install as a buildInput
          }
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
        internal = true;
        # hack because internal=true doesn't propagate to the submodule options
        visible = "shallow";
        type = t.lazyAttrsOf (t.submoduleWith {
          inherit specialArgs;
          modules = [dream2nix.modules.dream2nix.core];
        });
        description = "drv-parts modules that define python dependencies";
      };
    };
  };
}
