{config, ...}: let
  lib = config.lib;
  t = lib.types;
in {
  options = {
     = lib.mkOption {
      type = t.;
    };
  };
}
