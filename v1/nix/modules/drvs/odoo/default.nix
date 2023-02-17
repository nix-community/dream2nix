{config, lib, ...}: let
  l = lib // builtins;
  python = config.deps.python;

in {

  imports = [
    ../../drv-parts/mach-nix-xs
  ];

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs)
      postgresql
      fetchFromGitHub
      ;
  };

  pname = "odoo";
  version = "16.0";

  src = config.deps.fetchFromGitHub {
    owner = "odoo";
    repo = "odoo";
    # ref: 16.0
    rev = "2d42fd69cada3b1f2716c3d0a20bec6170f9b226";
    hash = "sha256-ZlPH+RaRZbWooe+kpiFYZtvuVmXtOMHeCW+Z74ZscXY=";
  };

  mach-nix.pythonSources = config.deps.fetchPythonRequirements {
    inherit (config.deps) python;
    name = config.pname;
    requirementsFiles = ["${config.src}/requirements.txt"];
    hash = "sha256-Ag4qTsgCTnnbK//T6OwME/OfknfNz5zDX3nSlCnIhSc=";
    maxDate = "2023-01-01";
    nativeBuildInputs = (with config.deps; [
      postgresql
    ]);
  };

  # Replace some python packages entirely with candidates from nixpkgs, because
  #   they are hard to fix
  mach-nix.substitutions = {
    python-ldap = python.pkgs.python-ldap;
    pillow = python.pkgs.pillow;
  };

  # fix some builds via overrides
  mach-nix.overrides = {
    libsass = old: {
      doCheck = false;
    };
    pypdf2 = old: {
      doCheck = false;
    };
  };

  mach-nix.manualSetupDeps.libsass = [
    "six"
  ];
}
