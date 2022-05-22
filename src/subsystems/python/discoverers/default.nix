{
  dlib,
  lib,
  subsystem,
}: let
  l = lib // builtins;

  discover = {tree}: let
    subdirProjects =
      l.flatten
      (l.mapAttrsToList
        (dirName: dir: discover {tree = dir;})
        (tree.directories or {}));
  in
    if tree ? files."setup.py"
    then
      [
        (dlib.construct.discoveredProject {
          inherit subsystem;
          relPath = tree.relPath;
          name =
            l.unsafeDiscardStringContext
            (l.last
              (l.splitString "/" (l.removeSuffix "/" "${tree.fullPath}")));
          translators = ["pip-WIP"];
          subsystemInfo.pythonAttr = "python3";
        })
      ]
      ++ subdirProjects
    else subdirProjects;
in {
  inherit discover;
}
