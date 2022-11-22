{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options = {
    dream2nix-interface = l.mkOption {
      type = t.lazyAttrsOf t.raw;
    };
  };
}
