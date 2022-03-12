{
  lib,
  # dream2nix
  apps,
  utils,
  ...
}: let
  l = lib // builtins;

  cli = apps.cli.program;
in
  utils.writePureShellScript
  []
  ''
    # disable test because we don't have a builder yet
    true
    # ${cli} add github:tweag/gomod2nix/67f22dd738d092c6ba88e420350ada0ed4992ae8 \
    #   --no-default-nix \
    #   --translator gomod2nix \
    #   --attribute-name gomod2nix
  ''
