{framework, ...}: let
  lib = framework.lib;
  t = lib.types;
in {
  options = {
    disabled = lib.mkOption {
      type = t.bool;
      default = false;
      description = "Whether to disable the discoverer, if disabled it can't be used.";
    };
    name = lib.mkOption {
      type = t.str;
      description = "Name of the discoverer.";
    };
    subsystem = lib.mkOption {
      type = t.str;
      description = "Subsystem of the discoverer.";
    };
    discover = lib.mkOption {
      type = t.functionTo (t.listOf t.attrs);
      default = _: {};
    };
  };
}
