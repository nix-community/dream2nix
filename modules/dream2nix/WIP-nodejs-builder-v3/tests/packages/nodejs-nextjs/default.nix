{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.WIP-nodejs-builder-v3
  ];

  mkDerivation = {
    src = ./nextjs-app;
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
  };

  WIP-nodejs-builder-v3 = {
    packageLockFile = "${config.mkDerivation.src}/package-lock.json";
  };

  name = "nextjs-app";
  version = "0.1.0";
}
