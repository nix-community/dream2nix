# NOTE: Move into top-level subdirectory to have all nix tooling in one place?
{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.drv-parts.mkDerivation
    dream2nix.modules.drv-parts.pip
  ];

  name = "pypkg1";
  version = "1";

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) stdenv;
  };

  mkDerivation = {
    src = ./.;
  };

  pip = {
    # NOTE: Pass via CLI or define once for multiple packages?
    pypiSnapshotDate = "2023-06-30";

    # NOTE: How do we select the optional dev dependencies?
    requirementsFile = [
      "."
    ];
  };
}