{
  dream2nix,
  config,
  lib,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.WIP-python-pyproject
  ];

  mkDerivation = {
    src = ./.;
  };
}
