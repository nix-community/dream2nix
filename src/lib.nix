# like ./default.nix but system intependent
# (allows to generate outputs for several systems)
# follows flake output schema
{
  nixpkgsSrc,
  lib,
  overridesDirs,
  externalSources,
  externalPaths,
} @ args: let
  l = lib // builtins;

  initDream2nix = config: pkgs:
    import ./default.nix
    {inherit config pkgs externalPaths externalSources;};

  loadConfig = config'': let
    config' = (import ./utils/config.nix).loadConfig config'';

    config =
      config'
      // {
        overridesDirs = args.overridesDirs ++ config'.overridesDirs;
      };
  in
    config;

  # TODO: design output schema for cross compiled packages
  makePkgsKey = pkgs: let
    build = pkgs.buildPlatform.system;
    host = pkgs.hostPlatform.system;
  in
    if build == host
    then build
    else throw "cross compiling currently not supported";

  makeNixpkgs = pkgsList: systems:
  # fail if neither pkgs nor systems are defined
    if pkgsList == null && systems == []
    then throw "Either `systems` or `pkgs` must be defined"
    # fail if pkgs and systems are both defined
    else if pkgsList != null && systems != []
    then throw "Define either `systems` or `pkgs`, not both"
    # only pkgs is specified
    else if pkgsList != null
    then
      if l.isList pkgsList
      then
        l.listToAttrs
        (pkgs: l.nameValuePair (makePkgsKey pkgs) pkgs)
        pkgsList
      else {"${makePkgsKey pkgsList}" = pkgsList;}
    # only systems is specified
    else
      l.genAttrs systems
      (system: import nixpkgsSrc {inherit system;});

  flakifyBuilderOutputs = system: outputs:
    l.mapAttrs
    (_: outputValue: {"${system}" = outputValue;})
    outputs;

  init = {
    pkgs ? throw "please pass 'pkgs' (a nixpkgs instance) to 'init'",
    config ? {},
  }:
    initDream2nix (loadConfig config) pkgs;

  makeFlakeOutputs = {
    source,
    pkgs ? null,
    systems ? [],
    systemsFromFile ? null,
    config ? {},
    inject ? {},
    pname ? throw "Please pass `pname` to makeFlakeOutputs",
    packageOverrides ? {},
    projects ? {},
    settings ? [],
    sourceOverrides ? oldSources: {},
  } @ args: let
    systems =
      if systemsFromFile == null
      then args.systems or []
      else dlib.systemsFromFile systemsFromFile;

    allPkgs = makeNixpkgs pkgs systems;

    config = loadConfig (args.config or {});
    dlib = import ./lib {inherit lib config;};

    initD2N = initDream2nix config;
    dream2nixFor = l.mapAttrs (_: pkgs: initD2N pkgs) allPkgs;

    discoveredProjects = dlib.discoverers.discoverProjects {
      inherit projects settings;
      tree = dlib.prepareSourceTree {inherit source;};
    };

    allBuilderOutputs =
      l.mapAttrs
      (system: pkgs: let
        dream2nix = dream2nixFor."${system}";
        allOutputs = dream2nix.makeOutputs {
          inherit
            source
            pname
            discoveredProjects
            settings
            sourceOverrides
            packageOverrides
            inject
            ;
        };
      in
        allOutputs)
      allPkgs;

    flakifiedOutputsList =
      l.mapAttrsToList
      (system: outputs: flakifyBuilderOutputs system outputs)
      allBuilderOutputs;

    flakeOutputsBuilders =
      l.foldl'
      (allOutputs: output: lib.recursiveUpdate allOutputs output)
      {}
      flakifiedOutputsList;

    flakeOutputs =
      {projectsJson = l.toJSON discoveredProjects;}
      // flakeOutputsBuilders;
  in
    flakeOutputs;

  makeFlakeOutputsForIndexes = {
    systems ? [],
    pkgs ? null,
    config ? {},
    source,
    indexes,
    inject ? {},
    packageOverrides ? {},
    settings ? [],
    sourceOverrides ? oldSources: {},
  }: let
    allPkgs = makeNixpkgs pkgs systems;

    config = loadConfig (args.config or {});
    dlib = import ./lib {inherit lib config;};

    initD2N = initDream2nix config;
    dream2nixFor = l.mapAttrs (_: pkgs: initD2N pkgs) allPkgs;

    allOutputs =
      l.mapAttrs
      (system: pkgs: let
        dream2nix = dream2nixFor."${system}";
        allOutputs = dream2nix.utils.makeOutputsForIndexes {
          inherit
            source
            indexes
            inject
            packageOverrides
            settings
            sourceOverrides
            ;
        };
      in
        allOutputs)
      allPkgs;

    flakifiedOutputsList =
      l.mapAttrsToList
      (system: outputs: flakifyBuilderOutputs system outputs)
      allOutputs;

    flakeOutputs =
      l.foldl'
      (allOutputs: output: lib.recursiveUpdate allOutputs output)
      {}
      flakifiedOutputsList;
  in
    flakeOutputs;
in rec {
  inherit init makeFlakeOutputs makeFlakeOutputsForIndexes;
  dlib = import ./lib {
    inherit lib;
    config = (import ./utils/config.nix).loadConfig {};
  };
  riseAndShine = throw "Use makeFlakeOutputs instead of riseAndShine.";
}
