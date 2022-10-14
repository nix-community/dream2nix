{config, ...}: let
  l = config.lib;

  fetchersDir = ../../fetchers;
  fetcherNames = l.attrNames (
    l.filterAttrs
    (_: type: type == "directory")
    (l.readDir fetchersDir)
  );
  fetcherModules =
    l.genAttrs
    fetcherNames
    (name: import "${fetchersDir}/${name}" config);
in {
  config = {
    fetchers = fetcherModules;
  };
}
