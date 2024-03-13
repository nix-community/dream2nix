{
  config,
  dream2nix,
  lib,
  packageSets,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
  cfg = config.php-granular;
  mkSubmodule = import ../../../lib/internal/mkSubmodule.nix {inherit lib specialArgs;};
in {
  options.php-granular = mkSubmodule {
    imports = [
      ../overrides
    ];
    config.overrideType = {
      imports = [
        dream2nix.modules.dream2nix.mkDerivation
      ];
    };
    options = l.mapAttrs (_: l.mkOption) {
      deps = {
        internal = true;
        visible = "shallow";
        type = t.lazyAttrsOf (t.lazyAttrsOf (t.submodule {
          imports = [
            dream2nix.modules.dream2nix.core
            cfg.overrideType
          ];
        }));
      };
      composerInstallFlags = {
        type = t.listOf t.str;
        default = [];
      };
    };
  };
}
