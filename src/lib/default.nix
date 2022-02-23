{
  lib,
  ...
}:
let

  l = lib // builtins;


  # INTERNAL

  listFiles = path: l.attrNames (l.filterAttrs (n: v: v == "regular") (builtins.readDir path));


  # EXPORTED

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
  ;
}
