{
  lib,
  ...
}:
let

  l = lib // builtins;


  # INTERNAL



  # EXPORTED

  listDirs = path: lib.attrNames (lib.filterAttrs (n: v: v == "directory") (builtins.readDir path));

  listFiles = path: l.attrNames (l.filterAttrs (n: v: v == "regular") (builtins.readDir path));

  # directory names of a given directory
  dirNames = dir: lib.attrNames (lib.filterAttrs (name: type: type == "directory") (builtins.readDir dir));

  # Returns true if every given pattern is satisfied by at least one file name
  # inside the given directory.
  # Sub-directories are not recursed.
  containsMatchingFile = patterns: dir:
    l.all
      (pattern: l.any (file: l.match pattern file != null) (listFiles dir))
      patterns;
in

{
  inherit
    containsMatchingFile
    dirNames
    listDirs
    listFiles
  ;
}
