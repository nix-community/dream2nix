{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options = {
    updaters = l.mkOption {
      type = t.lazyAttrsOf (t.functionTo t.path);
    };
  };
}
