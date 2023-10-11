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
      type = t.lazyAttrsOf (t.lazyAttrsOf (t.submodule {
        imports = [
          dream2nix.modules.dream2nix.core
          # TODO: fix this
          # putting mkDerivation here leads to an error when generating docs:
          #   The option `php-granular.deps.<name>.<name>.version' is used but not defined.
          # dream2nix.modules.dream2nix.mkDerivation
        ];
        _module.args = {inherit dream2nix packageSets;};
      }));
    };
    composerInstallFlags = {
      type = t.listOf t.str;
      default = [];
    };
  };
}
