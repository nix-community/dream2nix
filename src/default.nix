{
  pkgs ? import <nixpkgs> {},
  lib ? pkgs.lib,
  nix ? pkgs.writeScriptBin "nix" ''
    ${pkgs.nixUnstable}/bin/nix --option experimental-features "nix-command flakes" "$@"
  '',
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
    inherit nix;
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
  fetchers = callPackageDream ./fetchers {};

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

  # fetch only sources and do not build
  fetchSources =
    {
      dreamLock,
      fetcher ? null,
      extract ? false,
    }@args:
    let
      # if generic lock is a file, read and parse it
      dreamLock' = (utils.readDreamLock { inherit dreamLock; }).lock;

      fetcher =
        if args.fetcher == null then
          findFetcher dreamLock'
        else
          args.fetcher;

      fetched = fetcher {
        mainPackageName = dreamLock.generic.mainPackageName;
        mainPackageVersion = dreamLock.generic.mainPackageVersion;
        sources = dreamLock'.sources;
        sourcesCombinedHash = dreamLock'.generic.sourcesCombinedHash;
      };

      fetchedSources = fetched.fetchedSources;

    in
      fetched // {
        fetchedSources =
          if extract then
            lib.mapAttrs
              (key: source: utils.extractSource { inherit source; })
              fetchedSources
          else
            fetchedSources;
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


  # build a dream lock via a specific builder
  callBuilder =
    {
      builder,
      builderArgs,
      fetchedSources,
      dreamLock,
      inject,
      sourceOverrides,
    }@args:
      let

        # inject dependencies
        dreamLock = utils.dreamLock.injectDependencies args.dreamLock inject;

        dreamLockInterface = (utils.readDreamLock { inherit dreamLock; }).interface;

        changedSources = sourceOverrides args.fetchedSources;

        fetchedSources =
          args.fetchedSources // changedSources;

        buildPackageWithOtherBuilder =
          {
            builder,
            name,
            version,
            inject,
          }@args2:
          let
            subDreamLockLoaded =
              utils.readDreamLock {
                dreamLock =
                  utils.dreamLock.getSubDreamLock dreamLock name version;
              };

          in
            callBuilder {
              inherit builder builderArgs inject sourceOverrides;
              dreamLock =
                subDreamLockLoaded.lock;
              inherit fetchedSources;
            };

      in
        builder ( builderArgs // {

          inherit
            buildPackageWithOtherBuilder
          ;

          inherit (dreamLockInterface)
            buildSystemAttrs
            dependenciesRemoved
            getDependencies
            getCyclicDependencies
            mainPackageName
            mainPackageVersion
            packageVersions
          ;

          getSource = utils.dreamLock.getSource fetchedSources;

        });


  # build package defined by dream.lock
  riseAndShine = 
    {
      dreamLock,
      builder ? null,
      fetcher ? null,
      inject ? {},
      sourceOverrides ? oldSources: {},
      packageOverrides ? {},
      builderArgs ? {},
    }@args:
    let
      # if generic lock is a file, read and parse it
      dreamLockLoaded = utils.readDreamLock { inherit (args) dreamLock; };
      dreamLock = dreamLockLoaded.lock;
      dreamLockInterface = dreamLockLoaded.interface;

      builder' =
        if builder == null then
          findBuilder dreamLock
        else
          builder;

      fetcher' =
        if fetcher == null then
          findFetcher dreamLock
        else
          fetcher;

      fetchedSources = (fetchSources {
        inherit dreamLock;
        fetcher = fetcher';
      }).fetchedSources;

      builderOutputs = callBuilder {
        inherit
          dreamLock
          fetchedSources
          inject
          sourceOverrides
        ;
        builder = builder';
        builderArgs = (args.builderArgs or {}) // {
          inherit packageOverrides;
        };
      };
    in
      builderOutputs;
   
}
