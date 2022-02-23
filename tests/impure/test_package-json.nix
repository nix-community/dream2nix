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
    ${cli} add npm:eslint/8.4.0 \
      --no-default-nix \
      --translator package-json \
      --attribute-name eslint \
      --arg name="{automatic}" \
      --arg noDev=true \
      --arg nodejs=14 \
      --arg npmArgs=

    ${cli} update eslint --to-version 8.4.1
  ''
