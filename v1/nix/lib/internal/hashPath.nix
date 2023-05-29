{
  lib,
  runCommandLocal,
  nix,
  ...
}: let
  l = builtins // lib;

  # hash the contents of a path via `nix hash path`
  hashPath = algo: path: let
    hashPath = runCommandLocal "hash-${algo}" {} ''
      ${nix}/bin/nix --option experimental-features nix-command hash path ${path} | tr --delete '\n' > $out
    '';
  in
    l.readFile hashPath;
in
  hashPath
