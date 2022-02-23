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
    ${cli} add github:prettier/prettier/2.4.1 \
      --no-default-nix \
      --translator yarn-lock \
      --attribute-name prettier \
      --arg name="{automatic}" \
      --arg noDev=false \
      --arg nodejs=14 \
      --arg peer=false \
      --aggregate
  ''
