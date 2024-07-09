{
  dream2nix,
  config,
  lib,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.WIP-python-pyproject
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python310;
  };

  mkDerivation = {
    src = ./.;
  };

  # This is not strictly required, but setting it will keep most dependencies
  #   locked, even when new dependencies are added via pyproject.toml
}
