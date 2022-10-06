{
  callPackageDream,
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;
  fetchersDir = ../../fetchers;
  fetcherNames = l.attrNames (
    l.filterAttrs
    (_: type: type == "directory")
    (l.readDir fetchersDir)
  );
  fetcherModules =
    l.genAttrs
    fetcherNames
    (
      name:
        import "${fetchersDir}/${name}" {
          inherit dlib lib;
        }
    );
in {
  config = {
    fetchers = fetcherModules;
  };
}
