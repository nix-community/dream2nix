{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.pip = {
    flattenDependencies = l.mkOption {
      type = t.bool;
      description = ''
        Use all dependencies as top-level dependencies
      '';
      default = false;
    };
    ignoredDependencies = l.mkOption {
      type = t.listOf t.str;
      description = ''
        list of dependencies to ignore
      '';
      default = ["wheel"];
    };
  };
}
