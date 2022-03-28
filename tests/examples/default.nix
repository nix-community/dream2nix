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
      cd ./tmp
      nix flake lock --override-input dream2nix ${../../.}
      nix run .#resolveImpure
      nix flake check
      cd -
      rm -r tmp
    done
  ''
