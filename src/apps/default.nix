{
  lib,
  pkgs,
  # dream2nix
  callPackageDream,
  translators,
  ...
}: let
  b = builtins;
in rec {
  apps = {
    inherit contribute install;
  };

  flakeApps =
    lib.mapAttrs (
      appName: app: {
        type = "app";
        program = b.toString app.program;
      }
    )
    apps;

  # the contribute cli
  contribute = callPackageDream (import ./contribute) {};

  # instrall the framework to a specified location by copying the code
  install = callPackageDream (import ./install) {};
}
