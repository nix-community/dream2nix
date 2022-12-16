{config, ...}: let
  l = config.lib;
  t = l.types;
in {
  options.utils = {
    toTOML = config.dlib.mkFunction {
      type = t.attrs;
    };
  };
}
