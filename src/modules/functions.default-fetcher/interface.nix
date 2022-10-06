{lib, ...}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    functions.defaultFetcher = l.mkOption {
      type = t.functionTo t.attrs;
    };
  };
}
