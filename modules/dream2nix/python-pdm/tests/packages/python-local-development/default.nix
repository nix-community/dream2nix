{
  config,
  dream2nix,
  lib,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.WIP-python-pdm
  ];
  # select python 3.10
  deps = {nixpkgs, ...}: {
    python = nixpkgs.python310;
  };
  pdm.lockfile = ./pdm.lock;
  pdm.pyproject = ./pyproject.toml;
  pdm.group = "dev";
  mkDerivation = {
    src = ./.;
    buildInputs = [
      config.deps.python.pkgs.pdm-backend
    ];
  };
}
