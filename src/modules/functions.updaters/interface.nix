{config, ...}: let
  inherit (config.dlib) mkFunction;
  l = config.lib // builtins;
  t = l.types;
in {
  options.functions.updaters = {
    getUpdaterName = mkFunction {
      type = t.either t.str t.null;
    };
    makeUpdateScript = mkFunction {
      type = t.path;
    };
  };
}
