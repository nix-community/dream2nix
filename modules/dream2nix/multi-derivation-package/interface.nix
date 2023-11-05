{
  config,
  dream2nix,
  lib,
  specialArgs,
  ...
}: let
  t = lib.types;
  dreamTypes = import ../../../lib/types {
    inherit dream2nix lib specialArgs;
  };
in {
  options = {
    out = lib.mkOption {
      type = dreamTypes.drvPart;
      description = "default output 'out'";
    };
  };
}
