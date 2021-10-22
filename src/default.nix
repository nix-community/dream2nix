{
  pkgs ? import <nixpkgs> {},
  lib ? pkgs.lib,
  externalSources ?
    # if called via CLI, load externals via env
    if builtins ? getEnv && builtins.getEnv "d2nExternalSources" != "" then
      builtins.getEnv "d2nExternalSources"
    # load from default dircetory
    else
      ./external,
}:

let

  b = builtins;

  utils = callPackageDream ./utils {};

  callPackageDream = f: args: pkgs.callPackage f (args // {
    inherit builders;
    inherit callPackageDream;
    inherit externals;
    inherit externalSources;
    inherit fetchers;
    inherit dream2nixWithExternals;
    inherit translators;
    inherit utils;
  });

  externals = {
    npmlock2nix = pkgs.callPackage "${externalSources}/npmlock2nix/internal.nix" {};
    node2nix = nodejs: pkgs.callPackage "${externalSources}/node2nix/node-env.nix" { inherit nodejs; };
    nix-parsec = rec {
      lexer = import "${externalSources}/nix-parsec/lexer.nix" { inherit parsec; };
      parsec = import "${externalSources}/nix-parsec/parsec.nix";
    };
  };

  config = builtins.fromJSON (builtins.readFile ./config.json);

  # apps for CLI and installation
  apps = callPackageDream ./apps {};

  # builder implementaitons for all subsystems
  builders = callPackageDream ./builders {};

  # fetcher implementations
  fetchers = callPackageDream ./fetchers {
    inherit (config) allowBuiltinFetchers;
  };

  # updater modules to find newest package versions
  updaters = callPackageDream ./updaters {};

  # the translator modules and utils for all subsystems
  translators = callPackageDream ./translators {};

  # the location of the dream2nix framework for self references (update scripts, etc.)
  dream2nixWithExternals =
    if b.pathExists (./. + "/external") then
      ./.
    else
      pkgs.runCommand "dream2nix-full-src" {} ''
        cp -r ${./.} $out
        chmod +w $out
        mkdir $out/external
        ls -lah ${externalSources}
        cp -r ${externalSources}/* $out/external/
      '';

in

rec {

  inherit apps builders dream2nixWithExternals fetchers translators updaters utils;

  # automatically find a suitable builder for a given generic lock
  findBuilder = dreamLock:
    let
      buildSystem = dreamLock.generic.buildSystem;
    in
      if ! builders ? "${buildSystem}" then
        throw "Could not find any builder for subsystem '${buildSystem}'"
      else
        builders."${buildSystem}".default;


  # detect if granular or combined fetching must be used
  findFetcher = dreamLock:
      if null != dreamLock.generic.sourcesCombinedHash then
        fetchers.combinedFetcher
      else
        fetchers.defaultFetcher;


  # automatically parse dream.lock if passed as file
  parseLock = lock:
    if builtins.isPath lock || builtins.isString lock then
      builtins.fromJSON (builtins.readFile lock)
    else
      lock;

  # fetch only sources and do not build
  fetchSources =
    {
      dreamLock,
      fetcher ? findFetcher (parseLock dreamLock),
      sourceOverrides ? oldSources: {},
      allowBuiltinFetchers ? true,
    }:
    let
      # if generic lock is a file, read and parse it
      dreamLock' = (parseLock dreamLock);
      fetched = fetcher {
        inherit allowBuiltinFetchers;
        sources = dreamLock'.sources;
        sourcesCombinedHash = dreamLock'.generic.sourcesCombinedHash;
      };
      sourcesToReplace = sourceOverrides fetched.fetchedSources;
      sourcesOverridden = lib.mapAttrs (pname: source:
        sourcesToReplace."${pname}" or source
      ) fetched.fetchedSources;
      sourcesEnsuredOverridden = lib.mapAttrs (pname: source:
        if source == "unknown" then throw ''
          Source '${pname}' is unknown. Please override using:
          dream2nix.buildPackage {
            ...
            sourceOverrides = oldSources: {
              "${pname}" = ...;
            };
            ...
          };
        ''
        else source
      ) sourcesOverridden;
    in
      fetched // {
        fetchedSources = sourcesEnsuredOverridden;
      };

  
  justBuild =
    {
      source,
    }@args:
    let

      translatorsForSource = translators.translatorsForInput {
        inputFiles = [];
        inputDirectories = [ source ];
      };

      t =
        let
          trans = b.filter (t: t.compatible && b.elem t.type [ "pure" "ifd" ]) translatorsForSource;
        in
          if trans != [] then lib.elemAt trans 0 else
            throw "Could not find a suitable translator for input";

      dreamLock' = translators.translators."${t.subsystem}"."${t.type}"."${t.name}".translate {
        inputFiles = [];
        inputDirectories = [ source ];
      };

      dreamLock = lib.recursiveUpdate dreamLock' {
        sources."${dreamLock'.generic.mainPackageName}"."${dreamLock'.generic.mainPackageVersion}" = {
          type = "path";
          path = source;
          version = "unknown";
        };
      };

      argsForRise = b.removeAttrs args [ "source" ];

    in
      (riseAndShine ({
        inherit dreamLock;
      } // argsForRise)).package;


  # build package defined by dream.lock
  riseAndShine = 
    {
      dreamLock,
      builder ? findBuilder (parseLock dreamLock),
      fetcher ? findFetcher (parseLock dreamLock),
      sourceOverrides ? oldSources: {},
      packageOverrides ? {},
      builderArgs ? {},
      allowBuiltinFetchers ? true,
    }@args:
    let
      # if generic lock is a file, read and parse it
      dreamLock' = (parseLock dreamLock);

      builderOutputs = builder (
        {
          dreamLock = dreamLock';
          fetchedSources = (fetchSources {
            inherit dreamLock fetcher sourceOverrides allowBuiltinFetchers;
          }).fetchedSources;
        }
        // builderArgs
        // lib.optionalAttrs (packageOverrides != {}) {
          inherit packageOverrides;
        });
    in
      builderOutputs;
   
}
