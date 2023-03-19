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
    ../../drv-parts/rust-cargo-lock-legacy
  ];

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) fetchFromGitHub;
    inherit (nixpkgs) stdenv;
  };

  # public = {
  name = l.mkForce "ripgrep";
  version = l.mkForce "13.0.0";
  # };

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "BurntSushi";
      repo = "ripgrep";
      rev = config.version;
      sha256 = "sha256-udEh+Re2PeO3DnX4fQThsaT1Y3MBHFfrX5Q5EN2XrF0=";
    };
  };
}
