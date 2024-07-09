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
    requirementsList = ["${config.name}==${config.version}"];
  };
}
