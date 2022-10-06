{
  config,
  lib,
  ...
}: let
  t = lib.types;
in {
  imports = [
    ./functions.discoverers
    ./functions.fetchers
    ./functions.default-fetcher
    ./functions.combined-fetcher
    ./functions.translators
    ./functions.subsystem-loading
    ./builders
    ./discoverers
    ./discoverers.default-discoverer
    ./fetchers
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
