{
  lib,
  config,
  ...
}: let
  l = lib // builtins;
  system = config.deps.stdenv.system;
in {
  imports = [
    ../../drv-parts/nodejs-floco
  ];

  name = l.mkForce "prettier";
  version = l.mkForce "2.8.7";

  lock.lockFileRel =
    l.mkForce "/v1/nix/modules/drvs/prettier-floco/lock-${system}.json";

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
  };

  nodejs-floco.source = builtins.fetchTarball {
    url = "https://github.com/prettier/prettier/tarball/2.8.7";
    sha256 = "0jl7cs3wd1ipp6lyqsqndqln2arqj9d7wicv9hqlgc676i976wc0";
  };
}
