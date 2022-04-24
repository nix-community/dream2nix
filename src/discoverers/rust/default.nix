{
  dlib,
  lib,
  subsystem,
}: let
  l = lib // builtins;

  discoverCrates = {tree}: let
    cargoToml = tree.files."Cargo.toml".tomlContent or {};

    subdirCrates =
      l.flatten
      (l.mapAttrsToList
        (dirName: dir: discoverCrates {tree = dir;})
        (tree.directories or {}));
  in
    if cargoToml ? package.name
    then
      [
        {
          inherit (cargoToml.package) name version;
          inherit (tree) relPath fullPath;
        }
      ]
      ++ subdirCrates
    else subdirCrates;

  discoverProjects = {
    tree,
    crates,
  }: let
    cargoToml = tree.files."Cargo.toml".tomlContent;

    subdirProjects =
      l.flatten
      (l.mapAttrsToList
        (dirName: dir:
          discoverProjects {
            inherit crates;
            tree = dir;
          })
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
          subsystemInfo = {inherit crates;};
        })
      ]
      ++ subdirProjects
    else subdirProjects;

  discover = {tree}:
    discoverProjects {
      inherit tree;
      crates = discoverCrates {inherit tree;};
    };
in {
  inherit discover;
}
