{config, ...}: let
  lib = config.lib;
  t = lib.types;
  functionOption = lib.mkOption {
    type = t.uniq (t.functionTo t.attrs);
  };
in {
  options.functions.translators.nodejs = {
    getMetaFromPackageJson = functionOption;
    getPackageJsonDeps = functionOption;
    getWorkspaceLockFile = functionOption;
    getWorkspacePackageJson = functionOption;
    getWorkspacePackages = functionOption;
    getWorkspaceParent = functionOption;
  };
}
