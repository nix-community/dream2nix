{config, ...}: let
  l = config.lib // builtins;
  updatersDir = ../../updaters;
  updaterNames = l.attrNames (
    l.filterAttrs
    (_: type: type == "directory")
    (l.readDir updatersDir)
  );
  updaterModules =
    l.genAttrs
    updaterNames
    (name: import "${updatersDir}/${name}" config);
in {
  config = {
    updaters = updaterModules;
  };
}
