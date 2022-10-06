{
  apps,
  dlib,
  externals,
  externalSources,
  lib,
  pkgs,
  utils,
  dream2nixConfig,
}: let
  t = lib.types;
in {
  imports = [
    ./functions.discoverers
    ./functions.fetchers
    ./functions.default-fetcher
    ./functions.combined-fetcher
    ./functions.translators
    ./builders
    ./discoverers
    ./discoverers.default-discoverer
    ./fetchers
    ./translators
  ];
  options = {
    apps = lib.mkOption {
      type = t.raw;
    };
    lib = lib.mkOption {
      type = t.raw;
    };
    dlib = lib.mkOption {
      type = t.raw;
    };
    externals = lib.mkOption {
      type = t.raw;
    };
    externalSources = lib.mkOption {
      type = t.raw;
    };
    pkgs = lib.mkOption {
      type = t.raw;
    };
    utils = lib.mkOption {
      type = t.raw;
    };
    dream2nixConfig = lib.mkOption {
      type = t.raw;
    };
  };
  config = {
    inherit apps dlib externals externalSources pkgs utils dream2nixConfig;
    lib = lib // builtins;
  };
}
