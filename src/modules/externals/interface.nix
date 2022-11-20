{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options = {
    externals = l.mkOption {
      type = t.lazyAttrsOf t.raw;
    };
  };
}
