# like ./default.nix but system intependent
# (allows to generate outputs for several systems)
# follows flake output schema
{
  dlib,
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
    (lib.optionalAttrs (outputs ? "defaultPackage") {
      defaultPackage."${system}" = outputs.defaultPackage;
    })
    // (lib.optionalAttrs (outputs ? "packages") {
      packages."${system}" = outputs.packages;
    })
    // (lib.optionalAttrs (outputs ? "devShell") {
      devShell."${system}" = outputs.devShell;
    });

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
  in {
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

    builders =
      forAllSystems
      (system: pkgs:
        dream2nixFor."${system}".builders);
  };

  makeFlakeOutputsFunc = {
    builder ? null,
    pname ? null,
    pkgs ? null,
    source,
    systems ? [],
    translator ? null,
    translatorArgs ? {},
    ...
  } @ args: let
    config = args.config or ((import ./utils/config.nix).loadConfig {});

    argsForward = b.removeAttrs args ["config" "pname" "pkgs" "systems"];

    allPkgs = makeNixpkgs pkgs systems;

    forAllSystems = f: b.mapAttrs f allPkgs;

    dream2nixFor = forAllSystems (dream2nixForSystem config);

    translatorFound = dlib.translators.findOneTranslator {
      inherit source;
      translatorName = args.translator or null;
    };

    translatorFoundFor = forAllSystems (
      system: pkgs:
        with translatorFound;
          dream2nixFor
          ."${system}"
          .translators
          .translators
          ."${subsystem}"
          ."${type}"
          ."${name}"
    );

    invalidationHash = dlib.calcInvalidationHash {
      inherit source translatorArgs;
      translator = translatorFound.name;
    };

    specifyPnameError = throw ''
      Translator `${translatorFound.name}` could not automatically determine `pname`.
      Please specify `pname` when calling `makeFlakeOutputs`
    '';

    detectedName = translatorFound.projectName;

    pname =
      if args.pname or null != null
      then args.pname
      else if detectedName != null
      then detectedName
      else specifyPnameError;

    allBuilderOutputs =
      lib.mapAttrs
      (system: pkgs: let
        dream2nix = dream2nixFor."${system}";

        dreamLockJsonPath = with config; "${projectRoot}/${packagesDir}/${pname}/dream-lock.json";

        dreamLock = dream2nix.utils.readDreamLock {
          dreamLock = dreamLockJsonPath;
        };

        dreamLockExistsAndValid =
          b.pathExists dreamLockJsonPath
          && dreamLock.lock._generic.invalidationHash or "" == invalidationHash;

        result = translator: args:
          dream2nix.makeOutputs (argsForward
            // {
              # TODO: this triggers the translator finding routine a second time
              translator = translatorFound.name;
            });
      in
        if dreamLockExistsAndValid
        then
          # we need to override the source here as it is coming from
          # a flake input
          let
            defaultPackage = dreamLock.lock._generic.defaultPackage;
            defaultPackageVersion =
              dreamLock.lock._generic.packages."${defaultPackage}";
          in
            result translatorFound {
              source = dreamLockJsonPath;
              sourceOverrides = oldSources: {
                "${defaultPackage}"."${defaultPackageVersion}" =
                  args.source;
              };
            }
        else if b.elem translatorFound.type ["pure" "ifd"]
        then
          # warn the user about potentially slow on-the-fly evaluation
          b.trace ''
            ${"\n"}
            The dream-lock.json for input '${pname}' doesn't exist or is outdated.
            ...Falling back to on-the-fly evaluation (possibly slow).
            To speed up future evalutations run once:
              nix run .#resolve
          ''
          result
          translatorFound {}
        else
          # print error because impure translation is required first.
          # continue the evaluation anyways, as otherwise we won't have
          # the `resolve` app
          b.trace ''
            ${"\n"}
            ERROR:
              Some information is missing to build this project reproducibly.
              Please execute nix run .#resolve to resolve all impurities.
          ''
          {})
      allPkgs;

    flakifiedOutputsList =
      lib.mapAttrsToList
      (system: outputs: flakifyBuilderOutputs system outputs)
      allBuilderOutputs;

    flakeOutputs =
      b.foldl'
      (allOutputs: output: lib.recursiveUpdate allOutputs output)
      {}
      flakifiedOutputsList;
  in
    lib.recursiveUpdate
    flakeOutputs
    {
      apps = forAllSystems (system: pkgs: {
        resolve.type = "app";
        resolve.program = let
          utils = dream2nixFor."${system}".utils;

          # TODO: Too many calls to findOneTranslator.
          #   -> make findOneTranslator system independent
          translatorFound = dream2nixFor."${system}".translators.findOneTranslator {
            inherit source;
            translatorName = args.translator or null;
          };
        in
          b.toString
          (utils.makePackageLockScript {
            inherit source translatorArgs;
            packagesDir = config.packagesDir;
            translator = translatorFound.name;
          });
      });
    };
in {
  inherit dlib init;
  riseAndShine = throw "Use makeFlakeOutputs instead of riseAndShine.";
  makeFlakeOutpus = makeFlakeOutputsFunc;
}
