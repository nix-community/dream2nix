{
  config,
  lib,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.pip
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

  pip = {
    pypiSnapshotDate = "2023-01-01";
    requirementsList = ["${config.name}==${config.version}"];
  };
}
