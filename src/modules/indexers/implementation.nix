{config, ...}: let
  l = config.lib;
  indexerDir = ../../indexers;
  indexerModules = l.readDir indexerDir;
in {
  config = {
    indexers =
      l.mapAttrs
      (name: _: import "${indexerDir}/${name}" config)
      indexerModules;
  };
}
