{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;

  # get translators for the project
  getTranslators = tree:
    l.optional (tree.files ? "composer.lock") "composer-lock"
    ++ ["composer-json"];

  # discover php projects
  discover = {tree}: let
    currentProjectInfo = dlib.construct.discoveredProject {
      inherit (tree) relPath;
      name =
        tree.files."composer.json".jsonContent.name
        or (
          if tree.relPath != ""
          then tree.relPath
          else "unknown"
        );
      subsystem = "php";
      translators = getTranslators tree;
      subsystemInfo = {};
    };
  in
    if l.pathExists "${tree.fullPath}/composer.json"
    then [currentProjectInfo]
    else [];
in {
  inherit discover;
}
