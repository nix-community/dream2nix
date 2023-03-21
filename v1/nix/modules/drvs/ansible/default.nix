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
    python = nixpkgs.python39;
  };

  name = "ansible";
  version = "2.7.1";

  mkDerivation = {
    preUnpack = ''
      export src=$(ls ${config.mach-nix.pythonSources}/names/${config.name}/*);
    '';
  };

  buildPythonPackage = {
    format = "setuptools";

    pythonImportsCheck = [
      config.name
    ];
  };

  mach-nix.pythonSources = config.deps.fetchPip {
    inherit python;
    name = config.name;
    requirementsList = ["${config.name}==${config.version}"];
    hash = "sha256-dCo1llHcCiFrBOEd6mWhwqwVglsN2grSbcdBj8OzKDY=";
    maxDate = "2023-01-01";
  };
}
