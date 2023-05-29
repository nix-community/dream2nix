{
  config,
  options,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
  cfg = config.nodejs-package-lock;
in {
  options.nodejs-package-lock = l.mapAttrs (_: l.mkOption) {
    dreamLock = {
      type = t.attrs;
      internal = true;
      description = "The content of the dream2nix generated lock file";
    };
    packageJsonFile = {
      type = t.path;
      description = ''
        The package.json file to use.
      '';
      default = cfg.source + /package.json;
    };
    packageJson = {
      type = t.attrs;
      description = "The content of the package.json";
    };
    packageLockFile = {
      type = t.nullOr t.path;
      description = ''
        The package.json file to use.
      '';
      default = cfg.source + /package-lock.json;
    };
    packageLock = {
      type = t.attrs;
      description = "The content of the package-lock.json";
    };
    source = {
      type = t.either t.path t.package;
      description = "Source of the package";
      default = config.mkDerivation.src;
    };
    withDevDependencies = {
      type = t.bool;
      default = true;
      description = ''
        Whether to include development dependencies.
        Usually it's a bad idea to disable this, as development dependencies can contain important build time dependencies.
      '';
    };
    workspaces = {
      type = t.listOf t.str;
      description = ''
        Workspaces to include.
        Defaults to the ones defined in package.json.
      '';
    };
  };
}
