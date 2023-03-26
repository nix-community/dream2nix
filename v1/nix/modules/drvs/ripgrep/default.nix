{
  lib,
  config,
  drv-parts,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    drv-parts.modules.drv-parts.mkDerivation
    ../../drv-parts/dream2nix-legacy
  ];

  dream2nix-legacy = {
    subsystem = "rust";
    translator = "cargo-lock";
    builder = "build-rust-package";
    source = config.deps.fetchFromGitHub {
      owner = "BurntSushi";
      repo = "ripgrep";
      rev = config.version;
      sha256 = "sha256-udEh+Re2PeO3DnX4fQThsaT1Y3MBHFfrX5Q5EN2XrF0=";
    };
  };

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) fetchFromGitHub;
    inherit (nixpkgs) stdenv;
  };

  name = l.mkForce "ripgrep";
  version = l.mkForce "13.0.0";
}
