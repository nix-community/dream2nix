{
  config,
  options,
  lib,
  drv-parts,
  dream2nix,
  packageSets,
  ...
}: let
  l = lib // builtins;
  t = l.types;
  cfg = config.nodejs-floco;
in {
  options.nodejs-floco = l.mapAttrs (_: l.mkOption) {
    source = {
      type = t.either t.path t.package;
      description = "Source of the package";
    };
    pdefs = {
      type = t.raw;
      description = "flocos datastructure for nodejs packages";
      default = config.lock.content.floco.pdefs;
    };
    modules = {
      type = t.listOf t.raw;
      description = "floco modules to add";
      default = [];
    };
  };
}
