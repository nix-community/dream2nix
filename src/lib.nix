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
  b = builtins;

  l = lib // builtins;

  dream2nixForSystem = config: system: pkgs:
    import ./default.nix
    {inherit config externalPaths externalSources pkgs;};

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
      if b.isList pkgsList
      then
        lib.listToAttrs
        (pkgs: lib.nameValuePair (makePkgsKey pkgs) pkgs)
        pkgsList
      else {"${makePkgsKey pkgsList}" = pkgsList;}
    # only systems is specified
    else
      lib.genAttrs systems
      (system: import nixpkgsSrc {inherit system;});

  flakifyBuilderOutputs = system: outputs:
    l.mapAttrs
    (ouputType: outputValue: {"${system}" = outputValue;})
    outputs;

  init = {
    pkgs ? null,
    systems ? [],
    config ? {},
  } @ argsInit: let
    config' = (import ./utils/config.nix).loadConfig argsInit.config or {};

    config =
      config'
      // {
        overridesDirs = args.overridesDirs ++ config'.overridesDirs;
      };

    allPkgs = makeNixpkgs pkgs systems;

    forAllSystems = f: lib.mapAttrs f allPkgs;

    dream2nixFor = forAllSystems (dream2nixForSystem config);
  in
    if pkgs != null
    then dream2nixFor."${makePkgsKey pkgs}"
    else {
      riseAndShine = throw "Use makeFlakeOutputs instead of riseAndShine.";

      makeFlakeOutputs = mArgs:
        makeFlakeOutputsFunc
        (
          {inherit config pkgs systems;}
          // mArgs
        );

      apps =
        forAllSystems
        (system: pkgs:
          dream2nixFor."${system}".apps.flakeApps);

      defaultApp =
        forAllSystems
        (system: pkgs:
          dream2nixFor."${system}".apps.flakeApps.dream2nix);
    };

  makeFlakeOutputsFunc = {
    config ? {},
    inject ? {},
    pname ? throw "Please pass `pname` to makeFlakeOutputs",
    pkgs ? null,
    packageOverrides ? {},
    settings ? [],
    source,
    sourceOverrides ? oldSources: {},
    systems ? [],
    translator ? null,
    translatorArgs ? {},
  } @ args: let
    config = args.config or ((import ./utils/config.nix).loadConfig {});
    allPkgs = makeNixpkgs pkgs systems;
    forAllSystems = f: b.mapAttrs f allPkgs;
    dream2nixFor = forAllSystems (dream2nixForSystem config);
    dlib = import ./lib {inherit lib config;};

    discoveredProjects = dlib.discoverers.discoverProjects {
      inherit settings;
      tree = dlib.prepareSourceTree {inherit source;};
    };

    allBuilderOutputs =
      lib.mapAttrs
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
      lib.mapAttrsToList
      (system: outputs: flakifyBuilderOutputs system outputs)
      allBuilderOutputs;

    flakeOutputsBuilders =
      b.foldl'
      (allOutputs: output: lib.recursiveUpdate allOutputs output)
      {}
      flakifiedOutputsList;

    flakeOutputs =
      {projectsJson = l.toJSON discoveredProjects;}
      // flakeOutputsBuilders;
  in
    flakeOutputs;
in {
  inherit init;
  dlib = import ./lib {inherit lib;};
  riseAndShine = throw "Use makeFlakeOutputs instead of riseAndShine.";
  makeFlakeOutputs = makeFlakeOutputsFunc;
}
