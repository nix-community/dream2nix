{lib, ...}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    functions.fetchers.defaultFetcher = l.mkOption {
      type = t.functionTo t.attrs;
    };
  };
}
