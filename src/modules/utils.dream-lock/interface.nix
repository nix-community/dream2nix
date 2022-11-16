{config, ...}: let
  inherit (config.dlib) mkFunction;
  l = config.lib // builtins;
  t = l.types;
in {
  options.utils.dream-lock = {
    compressDreamLock = mkFunction {
      type = t.attrs;
    };
    decompressDreamLock = mkFunction {
      type = t.attrs;
    };
    getMainPackageSource = mkFunction {
      type = t.attrs;
    };
    getSource = mkFunction {
      type = t.functionTo (t.functionTo (t.either t.package t.path));
    };
    getSubDreamLock = mkFunction {
      type = t.functionTo (t.functionTo t.attrs);
    };
    readDreamLock = mkFunction {
      type = t.attrs;
    };
    replaceRootSources = mkFunction {
      type = t.attrs;
    };
    injectDependencies = mkFunction {
      type = t.functionTo t.attrs;
    };
    toJSON = mkFunction {
      type = t.attrs;
    };
  };
}
