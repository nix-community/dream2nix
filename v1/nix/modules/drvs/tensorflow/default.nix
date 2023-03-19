{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  python = config.deps.python;
in {
  imports = [
    ../../drv-parts/mach-nix-xs
  ];

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      postgresql
      fetchFromGitHub
      ;
  };

  name = "tensorflow";
  version = "2.11.0";

  mkDerivation = {
    preUnpack = ''
      export src=$(ls ${config.mach-nix.pythonSources}/names/${config.name}/*);
    '';
  };

  buildPythonPackage = {
    format = "wheel";
    pythonImportsCheck = [
      config.name
    ];
  };

  mach-nix.pythonSources = config.deps.fetchPythonRequirements {
    inherit (config.deps) python;
    name = config.name;
    requirementsList = ["${config.name}==${config.version}"];
    hash = "sha256-PDUrECFjoPznqXwqi2e1djx63t+kn/kAyM9JqQrTmd0=";
    maxDate = "2023-01-01";
  };
}
