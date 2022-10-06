{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options = {
    functions.combinedFetcher = l.mkOption {
      type = t.functionTo t.attrs;
    };
  };
}
