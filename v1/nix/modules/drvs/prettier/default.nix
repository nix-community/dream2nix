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

  legacy = {
    subsystem = "nodejs";
    translator = "yarn-lock";
    builder = "granular-nodejs";
    subsystemInfo = {
      nodejs = "16";
      noDev = false;
    };
    source = config.deps.fetchFromGitHub {
      owner = "prettier";
      repo = "prettier";
      rev = config.version;
      sha256 = "sha256-gHFzUjTHsEcxTJtFflqSOCthKW4Wa+ypuTeGxodmh0o=";
    };
  };

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) fetchFromGitHub;
    inherit (nixpkgs) stdenv;
  };

  name = l.mkForce "prettier";
  version = l.mkForce "2.8.7";
}
