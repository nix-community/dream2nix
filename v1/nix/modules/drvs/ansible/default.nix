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
    inherit (nixpkgs.writers) writePython3;
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

  mach-nix.pythonSources = {
    fetch-pip = {
      maxDate = "2023-01-01";
      requirementsList = ["${config.name}==${config.version}"];
    };
  };
}
