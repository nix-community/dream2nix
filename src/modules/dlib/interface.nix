{config, ...}: let
  inherit (config.dlib) mkFunction;
  l = config.lib // builtins;
  t = l.types;
in {
  options.dlib = {
    calcInvalidationHash = mkFunction {
      type = t.str;
    };
    callViaEnv = mkFunction {
      type = t.raw;
    };
    containsMatchingFile = mkFunction {
      type = t.bool;
    };
    dirNames = mkFunction {
      type = t.listOf t.str;
    };
    latestVersion = mkFunction {
      type = t.str;
    };
    listDirs = mkFunction {
      type = t.listOf t.str;
    };
    listFiles = mkFunction {
      type = t.listOf t.str;
    };
    mergeFlakes = mkFunction {
      type = t.attrs;
    };
    nameVersionPair = mkFunction {
      type = t.functionTo (t.attrsOf t.str);
    };
    prepareSourceTree = mkFunction {
      type = t.raw;
    };
    readTextFile = mkFunction {
      type = t.str;
    };
    recursiveUpdateUntilDepth = mkFunction {
      type = t.functionTo (t.functionTo t.attrs);
    };
    recursiveUpdateUntilDrv = mkFunction {
      type = t.functionTo t.attrs;
    };
    sanitizePath = mkFunction {
      type = t.either t.path t.str;
    };
    sanitizeRelativePath = mkFunction {
      type = t.str;
    };
    systemsFromFile = mkFunction {
      type = t.listOf t.str;
    };
    traceJ = mkFunction {
      type = t.functionTo t.raw;
    };
    isNotDrvAttrs = mkFunction {
      type = t.bool;
    };
    mkFunction = l.mkOption {
      type = t.functionTo t.attrs;
    };
  };
}
