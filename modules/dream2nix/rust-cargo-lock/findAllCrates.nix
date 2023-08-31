{lib, ...}: let
  discoverCrates = {
    tree,
    workspaceVersion,
  }: let
    cargoToml = tree.files."Cargo.toml".tomlContent or {};

    subdirCrates =
      lib.flatten
      (lib.mapAttrsToList
        (dirName: dir:
          discoverCrates {
            inherit workspaceVersion;
            tree = dir;
          })
        (tree.directories or {}));
  in
    if cargoToml ? package.name
    then
      [
        {
          inherit (cargoToml.package) name;
          inherit (tree) relPath;

          version =
            if cargoToml.package.version.workspace or false
            then workspaceVersion
            else cargoToml.package.version;
        }
      ]
      ++ subdirCrates
    else subdirCrates;
in
  {tree}:
    discoverCrates {
      inherit tree;
      workspaceVersion = tree.files."Cargo.toml".tomlContent.workspace.package.version or null;
    }
