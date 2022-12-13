# like ./default.nix but system intependent
# (allows to generate outputs for several systems)
# follows flake output schema
{
  nixpkgsSrc,
  lib,
  overridesDirs,
  externalSources,
  externalPaths,
  inputs,
} @ args: let
  l = lib // builtins;

  initDream2nix = config: pkgs:
    import ./modules/framework.nix {
      inherit lib inputs pkgs externalPaths externalSources;
      dream2nixConfig = config;
    };

  loadConfig = config'': let
    config' = import ./modules/config.nix {
      rawConfig = config'';
      inherit lib;
    };

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
        (map (pkgs: l.nameValuePair (makePkgsKey pkgs) pkgs) pkgsList)
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

  missingProjectsError = source: ''
    Please pass `projects` to makeFlakeOutputs.
    `projects` can be:
      - an attrset
      - a path to a .toml file (not empty & added to git)
      - a path to a .json file (not empty & added to git)

    To generate a projects.toml file automatically:
      1. execute:
        nix run .#detect-projects ${source} > projects.toml

        or alternatively:
        nix run github:nix-community/dream2nix#detect-projects ${source} > projects.toml

      2. review the ./projects.toml and edit it if necessary.
      3. pass `projects = ./projects.toml` to makeFlakeOutputs.

    Alternatively pass `autoProjects = true` to makeFlakeOutputs.
    This is not recommended as it doesn't allow you to review or filter the list
      of detected projects.
  '';

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
    autoProjects ? false,
    settings ? [],
    sourceOverrides ? oldSources: {},
  } @ args: let
    config = loadConfig (args.config or {});

    framework = import ./modules/framework.nix {
      inherit lib externalPaths externalSources inputs;
      dream2nixConfig = config;
      pkgs = throw "pkgs is not available before nixpkgs is imported";
    };

    systems =
      if systemsFromFile == null
      then args.systems or []
      else
        framework.dlib.systemsFromFile {
          inherit config;
          file = systemsFromFile;
        };

    # if projects provided via `.json` or `.toml` file, parse to attrset
    projects = let
      givenProjects = args.projects or {};
    in
      if autoProjects && args ? projects
      then throw "Don't pass `projects` to makeFlakeOutputs when `autoProjects = true`"
      else if l.isPath givenProjects
      then
        if l.hasSuffix ".toml" (l.toString givenProjects)
        then l.fromTOML (l.readFile givenProjects)
        else l.fromJSON (l.readFile givenProjects)
      else givenProjects;

    allPkgs = makeNixpkgs pkgs systems;

    initD2N = initDream2nix config;
    dream2nixFor = l.mapAttrs (_: pkgs: initD2N pkgs) allPkgs;

    discoveredProjects = framework.functions.discoverers.discoverProjects {
      inherit settings;
      tree = framework.dlib.prepareSourceTree {inherit source;};
    };

    finalProjects =
      if autoProjects == true
      then discoveredProjects
      else let
        projectsList = l.attrValues projects;
      in
        # skip discovery and just add required attributes to project list
        l.forEach projectsList
        (proj:
          proj
          // {
            relPath = proj.relPath or "";
            translator = proj.translator or (l.head proj.translators);
            dreamLockPath =
              framework.functions.discoverers.getDreamLockPath
              proj
              (l.head projectsList);
          });

    allBuilderOutputs =
      l.mapAttrs
      (system: pkgs: let
        dream2nix = dream2nixFor."${system}";
        allOutputs = dream2nix.dream2nix-interface.makeOutputs {
          discoveredProjects = finalProjects;
          inherit
            source
            pname
            settings
            sourceOverrides
            packageOverrides
            inject
            ;
        };
      in
        framework.dlib.recursiveUpdateUntilDrv
        allOutputs
        {
          apps.detect-projects =
            dream2nixFor.${system}.flakeApps.detect-projects;
        })
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

    errorFlakeOutputs = {
      apps =
        l.mapAttrs
        (system: pkgs: {
          detect-projects =
            dream2nixFor.${system}.flakeApps.detect-projects;

          error = throw (missingProjectsError source);
        })
        allPkgs;
    };

    finalOutputs = let
      givenProjects = args.projects or {};
    in
      if
        (givenProjects == {} && autoProjects == false)
        || (l.isPath givenProjects && ! l.pathExists givenProjects)
      then errorFlakeOutputs
      else flakeOutputsBuilders;
  in
    finalOutputs;

  makeFlakeOutputsForIndexes = {
    systems ? [],
    pkgs ? null,
    config ? {},
    source,
    indexes,
    inject ? {},
    packageOverrides ? {},
    sourceOverrides ? oldSources: {},
  }: let
    allPkgs = makeNixpkgs pkgs systems;

    config = loadConfig (args.config or {});

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
in {
  inherit init makeFlakeOutputs makeFlakeOutputsForIndexes;
  dlib = import ./modules/dlib.nix {inherit lib;};
  riseAndShine = throw "Use makeFlakeOutputs instead of riseAndShine.";
}
