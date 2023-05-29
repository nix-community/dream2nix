{
  lib,
  config,
  ...
}: let
  l = lib // builtins;
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
}
