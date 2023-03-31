{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    ../../drv-parts/buildPythonEnv
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python39;
  };

  name = "ansible";
  version = "2.7.1";

  buildPythonPackage = {
    pythonImportsCheck = [
      config.name
    ];
  };

  buildPythonEnv = {
    pypiSnapshotDate = "2023-01-01";
    requirementsList = ["${config.name}==${config.version}"];
  };
}
