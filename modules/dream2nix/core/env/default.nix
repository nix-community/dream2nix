{
  config,
  lib,
  packageSets,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    env = lib.mkOption {
      type = let
        baseTypes = [t.bool t.int t.str t.path t.package];
        allTypes = baseTypes ++ [(t.listOf (t.oneOf baseTypes))];
      in
        t.attrsOf (t.nullOr (t.oneOf allTypes));
      default = {};
      description = ''
        environment variables passed to the build environment
      '';
    };
  };
}
