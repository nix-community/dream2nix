{
  lib,
  config,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    ../../drv-parts/rust-cargo-lock
    ../../drv-parts/rust-crane
  ];

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) fetchFromGitHub;
  };

  name = l.mkForce "ripgrep";
  version = l.mkForce "13.0.0";

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "BurntSushi";
      repo = "ripgrep";
      rev = config.version;
      sha256 = "sha256-udEh+Re2PeO3DnX4fQThsaT1Y3MBHFfrX5Q5EN2XrF0=";
    };
  };
}
