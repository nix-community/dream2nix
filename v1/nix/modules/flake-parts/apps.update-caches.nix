{
  self,
  lib,
  inputs,
  ...
}: {
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    system,
    ...
  }: let
    l = lib // builtins;

    allNewFileCommands =
      l.flatten
      (l.mapAttrsToList
        (name: pkg: pkg.config.eval-cache.refresh or [])
        self'.packages);

    update-caches =
      config.writers.writePureShellScript
      (with pkgs; [
        coreutils
        git
        nix
      ])
      (
        "set -x\n"
        + (l.concatStringsSep "\n" allNewFileCommands)
      );

    toApp = script: {
      type = "app";
      program = "${script}";
    };
  in {
    apps = l.mapAttrs (_: toApp) {
      inherit
        update-caches
        ;
    };
  };
}
