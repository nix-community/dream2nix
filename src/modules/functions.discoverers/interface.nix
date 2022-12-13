{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options.functions.discoverers = {
    discoverProjects2 = l.mkOption {
      type = t.uniq (t.functionTo (t.listOf t.attrs));
    };
    discoverProjects = l.mkOption {
      type = t.uniq (t.functionTo (t.listOf t.attrs));
    };
    applyProjectSettings = l.mkOption {
      type = t.uniq (t.functionTo (t.functionTo (t.listOf t.attrs)));
    };
    getDreamLockPath = l.mkOption {
      type = t.uniq (t.functionTo (t.functionTo t.path));
    };
  };
}
