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
    ${cli} add github:mattermost/mattermost-webapp/v6.1.0 \
      --no-default-nix \
      --translator package-lock \
      --attribute-name mattermost-webapp \
      --arg name="{automatic}" \
      --arg noDev=false \
      --arg nodejs=14
  ''
