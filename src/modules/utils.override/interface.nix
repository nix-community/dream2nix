{config, ...}: let
  inherit (config.dlib) mkFunction;
  l = config.lib;
  t = l.types;
in {
  options.utils = {
    applyOverridesToPackage = mkFunction {
      type = t.attrs;
    };
    loadOverridesDirs = mkFunction {
      type = t.attrs;
    };
  };
}
