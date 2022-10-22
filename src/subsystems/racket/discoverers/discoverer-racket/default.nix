{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;

  discover = {
    tree,
    topLevel ? true,
  }:
    if (tree ? files."info.rkt")
    then [
      (dlib.construct.discoveredProject {
        subsystem = "racket";
        relPath = tree.relPath;
        name =
          if topLevel
          then "main"
          else
            l.unsafeDiscardStringContext
            (l.last
              (l.splitString "/" (l.removeSuffix "/" "${tree.fullPath}")));
        translators = ["racket-impure"];
        subsystemInfo = {};
      })
    ]
    else
      l.flatten (l.mapAttrsToList (_dirName: dirTree:
        discover {
          tree = dirTree;
          topLevel = false;
        }) (tree.directories or {}));
in {
  inherit discover;
}
