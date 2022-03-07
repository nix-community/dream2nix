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
    ${cli} add github:BurntSushi/ripgrep/13.0.0 \
      --no-default-nix \
      --translator cargo-lock \
      --arg packageName="ripgrep" \
      --attribute-name ripgrep
  ''
