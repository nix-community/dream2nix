{
  lib ? pkgs.lib,
  pkgs ? import <nixpkgs> {},
  dream2nix ? import ./src {inherit pkgs;},
}: let
  l = pkgs.lib // builtins;

  buildProjectsTests = import ./projects.nix {
    inherit lib pkgs dream2nix;
  };

  otherTests = import ./other {
    inherit lib pkgs dream2nix;
  };
in
  buildProjectsTests
  // otherTests
