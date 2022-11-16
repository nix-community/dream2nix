{
  dlib,
  externals,
  externalSources,
  inputs,
  lib,
  pkgs,
  dream2nixConfig,
  dream2nixConfigFile,
  dream2nixWithExternals,
} @ args: let
  t = lib.types;
in {
  imports = [
    ./functions.discoverers
    ./functions.fetchers
    ./functions.default-fetcher
    ./functions.combined-fetcher
    ./functions.translators
    ./apps
    ./builders
    ./discoverers
    ./discoverers.default-discoverer
    ./fetchers
    ./translators
    ./indexers
    ./utils
    ./utils.translator
    ./utils.index
    ./utils.override
    ./utils.toTOML
    ./utils.dream-lock
  ];
  options = {
    lib = lib.mkOption {
      type = t.raw;
    };
    dlib = lib.mkOption {
      type = t.raw;
    };
    externals = lib.mkOption {
      type = t.lazyAttrsOf t.raw;
    };
    externalSources = lib.mkOption {
      type = t.lazyAttrsOf t.path;
    };
    inputs = lib.mkOption {
      type = t.lazyAttrsOf t.attrs;
    };
    pkgs = lib.mkOption {
      type = t.raw;
    };
    dream2nixConfig = lib.mkOption {
      type = t.submoduleWith {
        modules = [./config];
      };
    };
    dream2nixWithExternals = lib.mkOption {
      type = t.path;
    };
    dream2nixConfigFile = lib.mkOption {
      type = t.path;
    };
  };
  config =
    args
    // {
      lib = args.lib // builtins;
    };
}
