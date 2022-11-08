{config, ...}: let
  l = config.lib;
  t = l.types;
in {
  options = {
    apps = l.mkOption {
      type = t.lazyAttrsOf (t.either t.path t.package);
    };
    flakeApps = l.mkOption {
      type = t.attrsOf t.raw;
    };
  };
}
