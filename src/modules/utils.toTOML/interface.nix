{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options.utils = {
    toTOML = config.dlib.mkFunction {
      type = t.attrs;
    };
  };
}
