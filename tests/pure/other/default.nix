{
  lib ? pkgs.lib,
  pkgs ? import <nixpkgs> {},
  dream2nix ? import ./src {inherit pkgs;},
}: let
  l = pkgs.lib // builtins;

  fetchAggrgatedGithub =
    dream2nix.utils.toDrv
    (dream2nix.fetchSources {
      dreamLock = ./prettier-github-aggregated.json;
    })
    .fetchedSources
    .prettier
    ."2.4.1";
in {
  inherit fetchAggrgatedGithub;
}
