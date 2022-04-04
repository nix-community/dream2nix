{
  dlib,
  lib,
  subsystem,
}: let
  l = lib // builtins;

  discover = {tree}: let
    cargoToml = tree.files."Cargo.toml".tomlContent;

    subdirProjects =
      l.flatten
      (l.mapAttrsToList
        (dirName: dir: discover {tree = dir;})
        (tree.directories or {}));
  in
    # A directory is identified as a project only if it contains a Cargo.toml
    # and a Cargo.lock.
    if
      tree
      ? files."Cargo.toml"
      && tree ? files."Cargo.lock"
    then
      [
        (dlib.construct.discoveredProject {
          inherit subsystem;
          relPath = tree.relPath;
          name = cargoToml.package.name or tree.relPath;
          translators = ["cargo-lock"];
          subsystemInfo = {};
        })
      ]
      ++ subdirProjects
    else subdirProjects;
in {
  inherit discover;
}
