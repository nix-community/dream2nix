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
    ./functions.discoverers
    ./translators
    ./builders
    ./discoverers
    ./default-discoverer
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
