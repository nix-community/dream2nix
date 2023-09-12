{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.rust-cargo-lock
    dream2nix.modules.dream2nix.rust-crane
  ];

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) fetchFromGitHub;
  };

  name = lib.mkForce "ripgrep";
  version = lib.mkForce "13.0.0";

  rust-crane = {
    # define the source root that contains the package we want to build.
    source = config.deps.fetchFromGitHub {
      owner = "BurntSushi";
      repo = "ripgrep";
      rev = config.version;
      sha256 = "sha256-udEh+Re2PeO3DnX4fQThsaT1Y3MBHFfrX5Q5EN2XrF0=";
    };
    # define additional options, such as build profile and flags
    # these can modify both derivations (main and dependencies)
    buildProfile = "dev";
    buildFlags = ["--verbose"];
    runTests = false;
    # options defined here will only apply to the resulting (`config.public`) derivation (main derivation).
    mainDrv = {
      env.CARGO_TERM_VERBOSE = "true";
    };
    # options defined here will only apply to the dependencies derivation.
    depsDrv = {
      env.CARGO_TERM_VERBOSE = "true";
    };
  };
}
