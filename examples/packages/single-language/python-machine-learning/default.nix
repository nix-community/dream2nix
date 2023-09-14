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

  # This is not strictly required, but setting it will keep most dependencies
  #   locked, even when new dependencies are added via pyproject.toml
  pip.pypiSnapshotDate = "2023-09-12";
}
