{
  lib,
  pkgs,
  framework,
  self,
  ...
}: let
  l = lib // builtins;
  specificationsDir = ../../../../src/specifications;
in
  framework.utils.writePureShellScript
  (with pkgs; [
    coreutils
    nix
  ])
  ''
    cd $TMPDIR
    cp -r ${specificationsDir}/* .
    chmod -R +w .
    specsDir=$(realpath .)
    ${pkgs.python3.pkgs.jsonschema}/bin/jsonschema \
      --instance $specsDir/dream-lock-example.json \
      --output pretty \
      --base-uri file:$specsDir/ \
      $specsDir/dream-lock-schema.json
  ''
