{
  config,
  lib,
  ...
}: let
  t = lib.types;
in {
  imports = [
    ./functions
    ./translators
  ];
  options = {
    lib = lib.mkOption {
      type = t.raw;
    };
  };
  config = {
    lib = lib // builtins;
  };
}
