{config, ...}: let
  lib = config.lib;
  t = lib.types;
in {
  options.functions.subsystem-loading = {
    collect = lib.mkOption {type = t.functionTo t.anything;};
    import_ = lib.mkOption {type = t.functionTo t.anything;};
    instantiate = lib.mkOption {type = t.functionTo t.anything;};
    structureBySubsystem = lib.mkOption {type = t.functionTo t.anything;};
  };
}
