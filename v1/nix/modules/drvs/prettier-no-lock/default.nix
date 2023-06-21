{
  lib,
  config,
  ...
}: let
  l = lib // builtins;
  system = config.deps.stdenv.system;
in {
  imports = [
    ../../drv-parts/nodejs-package-json
    ../../drv-parts/nodejs-granular
  ];

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "prettier";
      repo = "prettier";
      rev = config.version;
      sha256 = "sha256-gHFzUjTHsEcxTJtFflqSOCthKW4Wa+ypuTeGxodmh0o=";
    };
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
  };

  name = l.mkForce "prettier";
  version = l.mkForce "2.8.7";

  lock.lockFileRel =
    l.mkForce "/v1/nix/modules/drvs/prettier-no-lock/lock-${system}.json";
}
