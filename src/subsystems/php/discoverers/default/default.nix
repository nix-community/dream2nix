{
  dlib,
  lib,
  subsystem,
  ...
}: let
  l = lib // builtins;

  # get translators for the project
  getTranslators = path: let
    nodes = l.readDir path;
  in
    l.optional (nodes ? "composer.lock") "composer-lock"
    ++ ["composer-json"];

  # discover php projects
  discover = {tree}: let
    currentProjectInfo = dlib.construct.discoveredProject {
      inherit subsystem;
      inherit (tree) relPath;
      name = tree.files."composer.json".jsonContent.name or tree.relPath;
      translators = getTranslators tree.fullPath;
      subsystemInfo = {};
    };
  in
    if l.pathExists "${tree.fullPath}/composer.json"
    then [currentProjectInfo]
    else [];
in {
  inherit discover;
}
