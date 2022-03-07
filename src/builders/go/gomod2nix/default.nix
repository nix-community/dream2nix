{
  lib,
  pkgs,
  externals,
  ...
}: {
  fetchedSources,
  dreamLock,
}: let
  gomod2nixTOML =
    fetchedSources.mapAttrs
    dependencyObject.goName;
in
  externals.gomod2nixBuilder rec {
    pname = dreamLock.generic.mainPackage;
    version = dreamLock.sources."${pname}".version;
    src = fetchedSources."${pname}";
    modules = ./gomod2nix.toml;
  }
