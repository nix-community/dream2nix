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
    python = nixpkgs.python313;
  };

  name = "ansible";
  version = "2.7.1";

  buildPythonPackage = {
    pythonImportsCheck = [
      config.name
    ];
  };

  paths.lockFile = "lock.${config.deps.stdenv.system}.json";
  pip = {
    requirementsList = ["${config.name}==${config.version}"];
  };
}
