{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options.functions.discoverers = {
    discoverProjects = l.mkOption {
      type = t.functionTo (t.listOf t.attrs);
    };
    applyProjectSettings = l.mkOption {
      type = t.functionTo (t.functionTo (t.listOf t.attrs));
    };
    getDreamLockPath = l.mkOption {
      type = t.functionTo (t.functionTo t.path);
    };
  };
}
