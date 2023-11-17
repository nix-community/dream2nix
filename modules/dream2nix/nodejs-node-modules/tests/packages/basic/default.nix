{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-node-modules
    dream2nix.modules.dream2nix.nodejs-package-lock
  ];

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      mkShell
      stdenv
      ;
  };

  nodejs-package-lock = {
    source = ./.;
  };

  name = "app";
  version = "1.0.0";
  mkDerivation = {
    src = config.nodejs-package-lock.source;
  };
}
