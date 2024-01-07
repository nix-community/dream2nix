{
  config,
  lib,
  dream2nix,
  ...
}: let
  isSdist = lib.hasSuffix ".tar.gz" config.mkDerivation.src;
in {
  # enable overrides from nixpkgs
  imports = [dream2nix.modules.dream2nix.nixpkgs-overrides];
  nixpkgs-overrides.enable = isSdist;
  nixpkgs-overrides.exclude = ["propagatedBuildInputs"];
  # TODO: upstream: fix setuptools collision (build-hook propagates setuptools)
  buildPythonPackage.catchConflicts = ! isSdist;
}
