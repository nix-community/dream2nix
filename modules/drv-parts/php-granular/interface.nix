{
  config,
  dream2nix,
  packageSets,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.php-granular = l.mapAttrs (_: l.mkOption) {
    deps = {
      type = t.attrsOf (t.attrsOf (t.submodule {
        imports = [
          dream2nix.modules.drv-parts.core
          dream2nix.modules.drv-parts.mkDerivation
          ./interface.nix
        ];
        _module.args = {inherit dream2nix packageSets;};
      }));
    };
    composerInstallFlags = {
      type = t.listOf t.string;
      default = [];
    };
  };
}
