{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  python = config.deps.python;
  src = config.deps.fetchFromGitHub {
    owner = "odoo";
    repo = "odoo";
    # ref: 16.0
    rev = "2d42fd69cada3b1f2716c3d0a20bec6170f9b226";
    hash = "sha256-ZlPH+RaRZbWooe+kpiFYZtvuVmXtOMHeCW+Z74ZscXY=";
  };
in {
  imports = [
    ../../drv-parts/buildPythonEnv
  ];

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      postgresql
      fetchFromGitHub
      ;
    python = nixpkgs.python38;
  };

  name = "odoo";
  version = "16.0";

  mkDerivation = {
    inherit src;
  };

  buildPythonEnv = {
    pypiSnapshotDate = "2023-04-01";
    requirementsList = [
      "${src}"
    ];

    nativeBuildInputs = [config.deps.postgresql];

    # fix some builds via overrides
    drvs = {
      psycopg2.mkDerivation = {
        nativeBuildInputs = [config.deps.postgresql];
      };
      libsass.mkDerivation = {
        doCheck = false;
        doInstallCheck = l.mkForce false;
      };
      pypdf2.mkDerivation = {
        doCheck = false;
        doInstallCheck = l.mkForce false;
      };
    };
  };
}
