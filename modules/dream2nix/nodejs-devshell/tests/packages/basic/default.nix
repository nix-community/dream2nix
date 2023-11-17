{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-devshell
    dream2nix.modules.dream2nix.nodejs-package-lock
  ];

  nodejs-package-lock = {
    source = ./.;
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      mkShell
      rsync
      stdenv
      ;
  };

  name = "app";
  version = "1.0.0";

  mkDerivation = {
    src = config.nodejs-package-lock.source;
    # allow devshell to be built -> CI pipeline happy
    buildPhase = "mkdir $out";
  };
}
