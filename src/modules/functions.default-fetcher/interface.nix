{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options = {
    functions.defaultFetcher = l.mkOption {
      type = t.functionTo t.attrs;
    };
  };
}
