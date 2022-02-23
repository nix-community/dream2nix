{
  lib,
  ...
}:
let

  l = lib // builtins;


  # exported attributes
  dlib = {
    inherit
      calcInvalidationHash
      containsMatchingFile
      dirNames
      listDirs
      listFiles
      translators
    ;
  };

  # other libs
  translators = import ./translators.nix { inherit dlib lib; };


  # INTERNAL



  # EXPORTED

  # calculate an invalidation hash for given source translation inputs
  calcInvalidationHash =
    {
      source,
      translator,
      translatorArgs,
    }:
    l.hashString "sha256" ''
      ${source}
      ${translator}
      ${l.toString
        (l.mapAttrsToList (k: v: "${k}=${l.toString v}") translatorArgs)}
    '';

  # Returns true if every given pattern is satisfied by at least one file name
  # inside the given directory.
  # Sub-directories are not recursed.
  containsMatchingFile = patterns: dir:
    l.all
      (pattern: l.any (file: l.match pattern file != null) (listFiles dir))
      patterns;

  # directory names of a given directory
  dirNames = dir: lib.attrNames (lib.filterAttrs (name: type: type == "directory") (builtins.readDir dir));

  listDirs = path: lib.attrNames (lib.filterAttrs (n: v: v == "directory") (builtins.readDir path));

  listFiles = path: l.attrNames (l.filterAttrs (n: v: v == "regular") (builtins.readDir path));
in

dlib
