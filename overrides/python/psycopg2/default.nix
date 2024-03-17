{
  config,
  lib,
  dream2nix,
  ...
}: let
  isSdist = lib.hasSuffix ".tar.gz" config.mkDerivation.src;
in {
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) postgresql;
  };

  # enable overrides from nixpkgs
  imports = [dream2nix.modules.dream2nix.nixpkgs-overrides];
  nixpkgs-overrides.enable = isSdist;

  # add postgresql to nativeBuildInputs
  mkDerivation.nativeBuildInputs = lib.mkIf isSdist [config.deps.postgresql];
}
