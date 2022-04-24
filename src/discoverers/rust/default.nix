{
  dlib,
  lib,
  subsystem,
}: let
  l = lib // builtins;

  discoverCrates = {tree}: let
    cargoToml = tree.files."Cargo.toml".tomlContent or {};

    subdirProjects =
      l.flatten
      (l.mapAttrsToList
        (dirName: dir: discoverCrates {tree = dir;})
        (tree.directories or {}));
  in
    if cargoToml ? package.name
    then [
      {
        inherit (cargoToml.package) name version;
        inherit (tree) relPath fullPath;
      }
    ]
    else subdirCrates;

  _discover = {
    tree,
    crates,
  }: let
    cargoToml = tree.files."Cargo.toml".tomlContent;

    subdirProjects =
      l.flatten
      (l.mapAttrsToList
        (dirName: dir:
          _discover {
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
    _discover {
      inherit tree;
      crates = discoverCrates {inherit tree;};
    };
in {
  inherit discover;
}
