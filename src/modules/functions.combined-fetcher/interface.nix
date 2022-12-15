{config, ...}: let
  l = config.lib;
  t = l.types;
in {
  options = {
    functions.combinedFetcher = l.mkOption {
      type = t.uniq (t.functionTo t.attrs);
    };
  };
}
