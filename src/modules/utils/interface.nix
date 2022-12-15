{config, ...}: let
  inherit (config.dlib) mkFunction;
  l = config.lib;
  t = l.types;
in {
  options.utils = {
    scripts = {
      nixFFI = l.mkOption {
        type = t.path;
      };
      formatDreamLock = l.mkOption {
        type = t.path;
      };
      aggregateHashes = l.mkOption {
        type = t.path;
      };
    };
    toDrv = mkFunction {
      type = t.package;
    };
    hashPath = mkFunction {
      type = t.functionTo t.str;
    };
    hashFile = mkFunction {
      type = t.functionTo t.str;
    };
    writePureShellScript = mkFunction {
      type = t.functionTo t.package;
    };
    writePureShellScriptBin = mkFunction {
      type = t.functionTo (t.functionTo t.package);
    };
    extractSource = mkFunction {
      type = t.package;
    };
    satisfiesSemver = mkFunction {
      type = t.bool;
    };
    makeTranslateScript = mkFunction {
      type = t.package;
    };
  };
}
