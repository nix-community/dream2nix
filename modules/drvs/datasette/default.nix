{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.drv-parts.lock
    dream2nix.modules.drv-parts.pex
    dream2nix.modules.drv-parts.buildPythonEnv
  ];

  # FIXME remove, after setting a platform-independent default for all lock files
  lock.lockFileRel =
    l.mkForce "/modules/drvs/${config.name}/lock.json";

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python3;
    rustc = nixpkgs.rustc;
  };

  name = "datasette";
  version = "0.64.3";

  # Build a python environment with nixpkgs.python.buildENv from
  # config.pex.packages by adding each packages store path to extraLibs.
  buildPythonEnv = {
    extraLibs = l.map (pkg: pkg.public.out) (l.attrValues config.pex.packages);
  };

  # Here we lock the specficied version of datasette and the latest version of
  # sqlite-utils with all their extras enabled, but then build only with
  # with one extra, "rich" enabled for illustrative purposes
  pex = {
    requirementsList = ["${config.name}[rich,test,docs]==${config.version}" "sqlite-utils[test,docs]"];
    extras = ["rich"];
  };

  # Manual per-package overrides, we need to specify build.system-requires
  # here as they are not yet included in pex lock files
  pex.packages = {
    "cryptography" = {
      mkDerivation.buildInputs = [
        config.deps.python.pkgs.setuptools
        config.deps.python.pkgs.setuptools-rust
        config.deps.rustc
      ];
    };

    "pip" = {
      # FIXME build currently fails,
      mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.setuptools];
    };
    "markupsafe" = {
      mkDerivation.buildInputs = [config.deps.python.pkgs.setuptools];
    };
    "pygments-csv-lexer" = {
      mkDerivation.buildInputs = [config.deps.python.pkgs.setuptools];
    };
    "tornado" = {
      mkDerivation.buildInputs = [config.deps.python.pkgs.setuptools];
    };
  };
}
