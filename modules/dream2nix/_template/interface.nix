{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options = l.mapAttrs (_: l.mkOption) {
    # put options here
  };
}
