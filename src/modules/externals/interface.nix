{config, ...}: let
  l = config.lib;
  t = l.types;
in {
  options = {
    externals = l.mkOption {
      type = t.lazyAttrsOf t.raw;
    };
  };
}
