{config, ...}: let
  l = config.lib;
  t = l.types;
in {
  options.utils = {
    simpleTranslate = config.dlib.mkFunction {
      type = t.functionTo t.attrs;
    };
  };
}
