{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options.utils = {
    simpleTranslate = config.dlib.mkFunction {
      type = t.functionTo t.attrs;
    };
  };
}
