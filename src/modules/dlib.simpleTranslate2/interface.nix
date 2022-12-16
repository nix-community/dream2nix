{config, ...}: let
  inherit (config.dlib) mkFunction;
  l = config.lib;
  t = l.types;
in {
  options.dlib.simpleTranslate2 = {
    translate = mkFunction {
      type = t.attrs;
    };
    mkFinalObjects = mkFunction {
      type = t.functionTo (t.listOf t.attrs);
    };
    mkExportedFinalObjects = mkFunction {
      type = t.functionTo (t.listOf t.attrs);
    };
    mkRelevantFinalObjects = mkFunction {
      type = t.functionTo (t.listOf t.attrs);
    };
    makeDependencies = mkFunction {
      type = t.attrs;
    };
  };
}
