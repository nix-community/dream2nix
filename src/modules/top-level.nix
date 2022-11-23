{
  inputs ?
    (import ../../flake-compat.nix {
      src = ../../.;
      inherit (pkgs) system;
    })
    .inputs,
  lib ? pkgs.lib,
  pkgs ? import <nixpkgs> {},
  dream2nixConfig ?
    if builtins ? getEnv && builtins.getEnv "dream2nixConfig" != ""
    # if called via CLI, load config via env
    then builtins.toPath (builtins.getEnv "dream2nixConfig")
    # load from default directory
    else {},
  externalPaths ? null,
  externalSources ? null,
} @ args: let
  b = builtins;
  t = lib.types;

  externalDir =
    if externalPaths != null
    then
      (import ../utils/external-dir.nix {
        inherit externalPaths externalSources pkgs;
      })
    # if called via CLI, load externals via env
    else if b ? getEnv && b.getEnv "d2nExternalDir" != ""
    then ../. + (b.getEnv "d2nExternalDir")
    # load from default directory
    else ../external;

  externalSources =
    args.externalSources
    or (
      lib.genAttrs
      (lib.attrNames (builtins.readDir externalDir))
      (inputName: "${../. + externalDir}/${inputName}")
    );
in {
  imports = [
    ./functions.discoverers
    ./functions.fetchers
    ./functions.default-fetcher
    ./functions.combined-fetcher
    ./functions.translators
    ./functions.updaters
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
    ./dlib
    ./dlib.parsing
    ./dlib.construct
    ./dlib.simpleTranslate2
    ./updaters
    ./externals
    ./dream2nix-interface
  ];
  options = {
    lib = lib.mkOption {
      type = t.raw;
    };
    inputs = lib.mkOption {
      type = t.lazyAttrsOf t.attrs;
    };
    pkgs = lib.mkOption {
      type = t.raw;
    };
    externalDir = lib.mkOption {
      type = t.path;
    };
    externalPaths = lib.mkOption {
      type = t.listOf t.str;
    };
    externalSources = lib.mkOption {
      type = t.lazyAttrsOf t.path;
    };
    dream2nixWithExternals = lib.mkOption {
      type = t.path;
    };
    dream2nixConfig = lib.mkOption {
      type = t.submoduleWith {
        modules = [./config];
      };
    };
    dream2nixConfigFile = lib.mkOption {
      type = t.path;
    };
  };
  config = {
    inherit
      dream2nixConfig
      pkgs
      inputs
      externalPaths
      externalSources
      externalDir
      ;

    lib = lib // builtins;

    dream2nixConfigFile = b.toFile "dream2nix-config.json" (b.toJSON dream2nixConfig);

    # the location of the dream2nix framework for self references (update scripts, etc.)
    dream2nixWithExternals =
      if b.pathExists (../. + "/external")
      then ../.
      else let
        dream2nixSrc = pkgs.runCommandLocal "dream2nix-full-src" {} ''
          cp -r ${../../.} $out
          chmod +w $out/src
          mkdir $out/src/external
          cp -r ${externalDir}/* $out/src/external/
        '';
      in "${dream2nixSrc}/src";
  };
}
