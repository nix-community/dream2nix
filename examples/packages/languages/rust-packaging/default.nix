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
    inherit (nixpkgs) fetchFromGitHub iconv;
  };

  name = lib.mkForce "ripgrep";
  version = lib.mkForce "13.0.0";

  # options defined on top-level will be applied to the main derivation (the derivation that is exposed)
  mkDerivation = {
    # define the source root that contains the package we want to build.
    src = config.deps.fetchFromGitHub {
      owner = "BurntSushi";
      repo = "ripgrep";
      rev = config.version;
      sha256 = "sha256-udEh+Re2PeO3DnX4fQThsaT1Y3MBHFfrX5Q5EN2XrF0=";
    };
    buildInputs = lib.optionals config.deps.stdenv.isDarwin [config.deps.iconv];
  };

  rust-crane = {
    buildProfile = "dev";
    buildFlags = ["--verbose"];
    runTests = false;
    depsDrv = {
      # options defined here will be applied to the dependencies derivation
    };
  };
}
