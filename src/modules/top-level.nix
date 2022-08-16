{
  config,
  lib,
  ...
}: let
  t = lib.types;
in {
  imports = [
    ./functions.subsystem-loading
    ./functions.translators
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
