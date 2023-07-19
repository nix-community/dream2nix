{
  lib,
  config,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    ../../drv-parts/nodejs-devshell
  ];

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "davhau";
      repo = "prettier";
      rev = "2.8.7-package-lock";
      sha256 = "sha256-zo+WRV3VHja8/noC+iPydtbte93s5GGc3cYaQgNhlEY=";
    };
    # allow devshell to be built -> CI pipeline happy
    buildPhase = "mkdir $out";
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

  name = l.mkForce "prettier";
  version = l.mkForce "2.8.7";
}
