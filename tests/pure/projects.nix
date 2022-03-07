{
  lib ? pkgs.lib,
  pkgs ? import <nixpkgs> {},
  dream2nix ? import ./src {inherit pkgs;},
}: let
  lib = pkgs.lib // builtins;

  makeTest = {
    name,
    source,
    cmds,
  }: let
    outputs = dream2nix.makeOutputs {
      inherit source;
    };
    commandsToRun = cmds outputs;
  in
    pkgs.runCommand "test-${name}" {}
    (lib.concatStringsSep "\n" commandsToRun);

  projects = {
    prettier = {
      source = lib.fetchTarball {
        url = "https://github.com/prettier/prettier/tarball/2.4.1";
        sha256 = "19b37qakhlsnr2n5bgv83aih5npgzbad1d2p2rs3zbq5syqbxdyi";
      };
      cmds = outputs: let
        prettier = outputs.defaultPackage.overrideAttrs (old: {
          dontBuild = true;
        });
      in [
        "${prettier}/bin/prettier --version | grep -q 2.4.1 && mkdir $out"
      ];
    };
  };

  allTests =
    lib.mapAttrs
    (name: args: makeTest (args // {inherit name;}))
    projects;
in
  allTests
