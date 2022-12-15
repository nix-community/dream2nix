{config, ...}: let
  l = config.lib;
  t = l.types;
in {
  options = {
    functions.defaultFetcher = l.mkOption {
      type = t.uniq (t.functionTo t.attrs);
    };
  };
}
