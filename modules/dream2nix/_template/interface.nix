{
  config,
  lib,
  ...
}: let
  t = lib.types;
in {
  options = lib.mapAttrs (_: lib.mkOption) {
    # put options here
  };
}
