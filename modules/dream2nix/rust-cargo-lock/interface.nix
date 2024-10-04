{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.rust-cargo-lock = l.mapAttrs (_: l.mkOption) {
    cargoLock = {
      type = t.path;
      internal = true;
      description = "The dreamlock that was generated as a Cargo.lock file";
    };
    dreamLock = {
      type = t.attrs;
      internal = true;
      description = "The content of the dream2nix generated lock file";
    };
    writeCargoLock = {
      type = t.str;
      internal = true;
      description = "Shell commands to backup original Cargo.lock and use dream2nix one in a rust derivation";
    };
    source = {
      type = t.either t.path t.package;
      description = "Source of the package";
      default = config.mkDerivation.src;
      defaultText = "config.mkDerivation.src";
    };
  };
}
