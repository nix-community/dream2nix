{
  self,
  lib,
  coreutils,
  nix,
  utils,
  dream2nixWithExternals,
  ...
}: let
  l = lib // builtins;
  examples = ../../examples;
in
  utils.writePureShellScript
  [
    coreutils
    nix
  ]
  ''
    for dir in $(ls ${examples}); do
      mkdir tmp
      cp ${examples}/$dir/* ./tmp/
      chmod -R +w ./tmp
      nix flake lock --override-input dream2nix ${../../.} ./tmp
      nix flake check ./tmp
      rm -r tmp
    done
  ''
