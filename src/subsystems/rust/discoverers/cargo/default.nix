{
  lib,
  dlib,
  ...
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
          inherit (tree) relPath;
        }
      ]
      ++ subdirCrates
    else subdirCrates;

  discoverProjects = {
    tree,
    crates,
  }: let
    cargoToml = tree.files."Cargo.toml".tomlContent;

    hasCargoToml = tree ? files."Cargo.toml";
    hasCargoLock = tree ? files."Cargo.lock";

    # "cargo-toml" translator is always added (a Cargo.toml should always be there).
    # "cargo-lock" translator is only available if the tree has a Cargo.lock.
    translators =
      (l.optional hasCargoLock "cargo-lock")
      ++ (l.optional hasCargoToml "cargo-toml");

    # get all workspace members
    workspaceMembers =
      l.flatten
      (
        l.map
        (
          memberName: let
            components = l.splitString "/" memberName;
          in
            # Resolve globs if there are any
            if l.last components == "*"
            then let
              parentDirRel = l.concatStringsSep "/" (l.init components);
              dirs = (tree.getNodeFromPath parentDirRel).directories;
            in
              l.mapAttrsToList
              (name: _: "${parentDirRel}/${name}")
              dirs
            else memberName
        )
        (l.optionals hasCargoToml (cargoToml.workspace.members or []))
      );

    # get projects in the subdirectories
    subdirProjects' =
      l.flatten
      (l.mapAttrsToList
        (dirName: dir:
          discoverProjects {
            inherit crates;
            tree = dir;
          })
        (tree.directories or {}));
    # filter the subdir projects so we don't add a Cargo project duplicate.
    # a duplicate can occur if a virtual Cargo manifest (a workspace)
    # declares a member crate, but this member crate is also detected
    # by dream2nix's discoverer as a separate project.
    subdirProjects =
      l.filter
      (
        project:
          !(
            l.any
            (memberPath: l.hasSuffix memberPath project.relPath)
            workspaceMembers
          )
      )
      subdirProjects';
  in
    # a directory is identified as a project if it contains a Cargo.toml.
    if hasCargoToml
    then
      [
        (dlib.construct.discoveredProject {
          inherit translators;
          subsystem = "rust";
          relPath = tree.relPath;
          name = cargoToml.package.name or tree.relPath;
          subsystemInfo = {inherit crates workspaceMembers;};
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
