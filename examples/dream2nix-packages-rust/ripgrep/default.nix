{
  lib,
  config,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.drv-parts.rust-cargo-lock
    dream2nix.modules.drv-parts.rust-crane
  ];

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) fetchFromGitHub;
  };

  name = l.mkForce "ripgrep";
  version = l.mkForce "13.0.0";

  mkDerivation = {
    # define the source root that contains the package we want to build.
    src = config.deps.fetchFromGitHub {
      owner = "BurntSushi";
      repo = "ripgrep";
      rev = config.version;
      sha256 = "sha256-udEh+Re2PeO3DnX4fQThsaT1Y3MBHFfrX5Q5EN2XrF0=";
    };
    # note: any more options defined here will be applied to both
    # `rust-crane.mainDrvOptions` and `rust-crane.depsDrvOptions`.
  };

  rust-crane = {
    buildProfile = "dev";
    buildFlags = ["--verbose"];
    runTests = false;
  };
}
