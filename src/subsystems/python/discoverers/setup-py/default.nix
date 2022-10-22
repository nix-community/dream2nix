{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;

  discover = {
    tree,
    topLevel ? true,
  }: let
    subdirProjects =
      l.flatten
      (l.mapAttrsToList
        (dirName: dir:
          discover {
            tree = dir;
            topLevel = false;
          })
        (tree.directories or {}));
  in
    if tree ? files."setup.py"
    then
      [
        (dlib.construct.discoveredProject {
          relPath = tree.relPath;
          name =
            if topLevel
            then "main"
            else
              l.unsafeDiscardStringContext
              (l.last
                (l.splitString "/" (l.removeSuffix "/" "${tree.fullPath}")));
          subsystem = "python";
          translators = ["pip"];
          subsystemInfo.pythonAttr = "python3";
        })
      ]
      ++ subdirProjects
    else subdirProjects;
in {
  inherit discover;
}
