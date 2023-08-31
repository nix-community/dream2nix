{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.rust-cargo-lock = l.mapAttrs (_: l.mkOption) {
    dreamLock = {
      type = t.attrs;
      internal = true;
      description = "The content of the dream2nix generated lock file";
    };
    source = {
      type = t.either t.path t.package;
      description = "Source of the package";
      default = config.mkDerivation.src;
    };
  };
}
