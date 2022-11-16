{config, ...}: let
  l = config.lib // builtins;
  t = l.types;

  mkFunction = {type, ...} @ attrs:
    l.mkOption (
      attrs
      // {
        type = t.uniq (t.functionTo attrs.type);
      }
    );
in {
  options.utils = {
    dreamLock = {
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
    toDrv = mkFunction {
      type = t.package;
    };
    toTOML = mkFunction {
      type = t.str;
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
    applyOverridesToPackage = mkFunction {
      type = t.attrs;
    };
    loadOverridesDirs = mkFunction {
      type = t.attrs;
    };
    simpleTranslate = mkFunction {
      type = t.functionTo t.attrs;
    };
    generatePackagesFromLocksTree = mkFunction {
      type = t.attrsOf t.package;
    };
    makeOutputsForIndexes = mkFunction {
      type = t.attrs;
    };
  };
}
