{lib, ...}: let
  discoverCrates = {tree}: let
    cargoToml = tree.files."Cargo.toml".tomlContent or {};

    subdirCrates =
      lib.flatten
      (lib.mapAttrsToList
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
in
  discoverCrates
