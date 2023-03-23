# custom app to update the eval-cache of each exported package.
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
        (name: pkg: pkg.config.lock.refresh or [])
        self'.packages);

    update-locks =
      config.writers.writePureShellScript
      (with pkgs; [
        coreutils
        git
        nix
      ])
      (
        "set -x\n"
        + (l.concatStringsSep "/bin/refresh\n" allNewFileCommands)
        + "/bin/refresh"
      );

    toApp = script: {
      type = "app";
      program = "${script}";
    };
  in {
    apps = l.mapAttrs (_: toApp) {
      inherit
        update-locks
        ;
    };
  };
}
