{
  lib,
  runCommandLocal,
  nix,
  ...
}: let
  l = builtins // lib;

  # hash a file via `nix hash file`
  hashFile = algo: path: let
    hashFile = runCommandLocal "hash-${algo}" {} ''
      ${nix}/bin/nix --option experimental-features nix-command hash file ${path} | tr --delete '\n' > $out
    '';
  in
    l.readFile hashFile;
in
  hashFile
