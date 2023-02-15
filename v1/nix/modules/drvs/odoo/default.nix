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

  pythonSources = config.deps.fetchPythonRequirements {
    inherit (config.deps) python;
    name = config.pname;
    requirementsFiles = ["${config.src}/requirements.txt"];
    hash = "sha256-fxvuknvfNQxRnUo8UWyvLdqAHrKxQMsWYXeKtEV0rns=";
    maxDate = "2023-01-01";
    nativeBuildInputs = (with config.deps; [
      postgresql
    ]);
  };

  # Replace some python packages entirely with candidates from nixpkgs, because
  #   they are hard to fix
  substitutions = {
    python-ldap = python.pkgs.python-ldap;
    pillow = python.pkgs.pillow;
  };

  # fix some builds via overrides
  overrides = {
    libsass = old: {
      doCheck = false;
    };
    pypdf2 = old: {
      doCheck = false;
    };
  };

  manualSetupDeps.libsass = [
    "six"
  ];
}
