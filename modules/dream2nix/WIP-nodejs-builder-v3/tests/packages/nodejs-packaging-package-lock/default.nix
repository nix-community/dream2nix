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
    src = config.deps.fetchFromGitHub {
      owner = "DavHau";
      repo = "cowsay";
      rev = "package-lock-v3";
      sha256 = "sha256-KuZkGWl5An78IFR5uT/2jVTXdm71oWB+p143svYVkqQ=";
    };
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

  name = "cowsay";
  version = "1.5.0";
}
