{config, ...}: let
  inherit (config.dlib) mkFunction;
  l = config.lib;
  t = l.types;
in {
  options.dlib.construct = {
    discoveredProject = mkFunction {
      type = t.attrs;
    };
    pathSource = mkFunction {
      type = t.attrs;
    };
  };
}
