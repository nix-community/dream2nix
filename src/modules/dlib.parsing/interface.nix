{config, ...}: let
  inherit (config.dlib) mkFunction;
  l = config.lib // builtins;
  t = l.types;
in {
  options.dlib = {
    identifyGitUrl = mkFunction {
      type = t.bool;
    };
    parseGitUrl = mkFunction {
      type = t.attrs;
    };
  };
}
