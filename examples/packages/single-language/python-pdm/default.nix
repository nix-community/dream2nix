{
  config,
  dream2nix,
  lib,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.WIP-python-pdm
  ];
  pdm.lockfile = ./pdm.lock;
  pdm.pyproject = ./pyproject.toml;
  pdm.pythonInterpreter = config.deps.python3;
  mkDerivation = {
    src = ./.;
    buildInputs = [
      config.deps.python3.pkgs.pdm-backend
    ];
  };
}
