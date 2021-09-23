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

  utils = callPackage ./utils.nix {};

  callPackage = f: args: pkgs.callPackage f (args // {
    inherit callPackage;
    inherit externals;
    inherit externalSources;
    inherit location;
    inherit translators;
    inherit utils;
  });

  externals = {
    npmlock2nix = pkgs.callPackage "${externalSources}/npmlock2nix/internal.nix" {};
    node2nix = nodejs: pkgs.callPackage "${externalSources}/node2nix/node-env.nix" { inherit nodejs; };
  };

  config = builtins.fromJSON (builtins.readFile ./config.json);

  # apps for CLI and installation
  apps = callPackage ./apps {};

  # builder implementaitons for all subsystems
  builders = callPackage ./builders {};

  # fetcher implementations
  fetchers = callPackage ./fetchers {
    inherit (config) allowBuiltinFetchers;
  };

  # the translator modules and utils for all subsystems
  translators = callPackage ./translators {};


  # the location of the dream2nix framework for self references (update scripts, etc.)
  location = ./.;

in

rec {

  inherit apps builders fetchers location translators;

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
      builder ? findBuilder (parseLock dreamLock),
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


  # build package defined by dream.lock
  # TODO: rename to riseAndShine
  buildPackage = 
    {
      dreamLock,
      builder ? findBuilder (parseLock dreamLock),
      fetcher ? findFetcher (parseLock dreamLock),
      sourceOverrides ? oldSources: {},
      allowBuiltinFetchers ? true,
    }@args:
    let
      # if generic lock is a file, read and parse it
      dreamLock' = (parseLock dreamLock);
    in
    builder {
      dreamLock = dreamLock';
      fetchedSources = (fetchSources args).fetchedSources;
    };
   
}
