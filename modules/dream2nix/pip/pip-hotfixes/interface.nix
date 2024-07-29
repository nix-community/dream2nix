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
        Use all dependencies as top-level dependencies, even transitive ones.

        Without this, we would walk the dependency tree from the root package upwards,
        adding only the necessary packages to each dependency. With this, it's flat.

        Useful if we are mostly interested in a working environment.
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
