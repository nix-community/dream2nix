# This is the system specific api for dream2nix.
# It requires passing one specific pkgs.
# If the intention is to generate output for several systems,
# use ./lib.nix instead.
{
  pkgs ? import <nixpkgs> {},
  dlib ? import ./lib {inherit config lib;},
  lib ? pkgs.lib,
  nix ? pkgs.nix,
  # default to empty dream2nix config
  config ?
  # if called via CLI, load config via env
  if builtins ? getEnv && builtins.getEnv "dream2nixConfig" != ""
  then builtins.toPath (builtins.getEnv "dream2nixConfig")
  # load from default directory
  else {},
  # dependencies of dream2nix
  externalSources ?
    lib.genAttrs
    (lib.attrNames (builtins.readDir externalDir))
    (inputName: "${/. + externalDir}/${inputName}"),
  # will be defined if called via flake
  externalPaths ? null,
  # required for non-flake mode
  externalDir ?
  # if flake is used, construct external dir from flake inputs
  if externalPaths != null
  then
    (import ./utils/external-dir.nix {
      inherit externalPaths externalSources pkgs;
    })
  # if called via CLI, load externals via env
  else if builtins ? getEnv && builtins.getEnv "d2nExternalDir" != ""
  then /. + (builtins.getEnv "d2nExternalDir")
  # load from default directory
  else ./external,
} @ args: let
  argsConfig = config;
in let
  b = builtins;

  l = lib // builtins;

  config = (import ./utils/config.nix).loadConfig argsConfig;

  configFile = pkgs.writeText "dream2nix-config.json" (b.toJSON config);

  # like pkgs.callPackage, but includes all the dream2nix modules
  callPackageDream = f: fargs:
    pkgs.callPackage f (fargs
      // {
        inherit apps;
        inherit callPackageDream;
        inherit config;
        inherit configFile;
        inherit dlib;
        inherit externals;
        inherit externalSources;
        inherit fetchers;
        inherit indexers;
        inherit dream2nixWithExternals;
        inherit utils;
        inherit nix;
        inherit subsystems;
        dream2nixInterface = {
          inherit
            makeOutputsForDreamLock
            ;
        };
      });

  utils = callPackageDream ./utils {};

  # apps for CLI and installation
  apps = callPackageDream ./apps {};

  # fetcher implementations
  fetchers = callPackageDream ./fetchers {};

  # indexer implementations
  indexers = callPackageDream ./indexers {};

  # updater modules to find newest package versions
  updaters = callPackageDream ./updaters {};

  subsystems = callPackageDream ./subsystems {};

  externals = {
    node2nix = nodejs:
      pkgs.callPackage "${externalSources.node2nix}/nix/node-env.nix" {
        inherit nodejs;
      };
    crane = let
      importLibFile = name: import "${externalSources.crane}/lib/${name}.nix";

      makeHook = attrs: name:
        pkgs.makeSetupHook
        ({inherit name;} // attrs)
        "${externalSources.crane}/pkgs/${name}.sh";
      genHooks = names: attrs: lib.genAttrs names (makeHook attrs);
    in
      {
        cargoHostTarget,
        cargoBuildBuild,
      }: rec {
        otherHooks = genHooks [
          "configureCargoCommonVarsHook"
          "configureCargoVendoredDepsHook"
          "remapSourcePathPrefixHook"
        ] {};
        installHooks =
          genHooks [
            "inheritCargoArtifactsHook"
            "installCargoArtifactsHook"
          ] {
            substitutions = {
              zstd = "${pkgs.pkgsBuildBuild.zstd}/bin/zstd";
            };
          };
        installLogHook = genHooks ["installFromCargoBuildLogHook"] {
          substitutions = {
            cargo = "${cargoBuildBuild}/bin/cargo";
            jq = "${pkgs.pkgsBuildBuild.jq}/bin/jq";
          };
        };

        # These aren't used by dream2nix
        crateNameFromCargoToml = null;
        vendorCargoDeps = null;

        writeTOML = importLibFile "writeTOML" {
          inherit (pkgs) runCommand pkgsBuildBuild;
        };
        cleanCargoToml = importLibFile "cleanCargoToml" {};
        findCargoFiles = importLibFile "findCargoFiles" {
          inherit (pkgs) lib;
        };
        mkDummySrc = importLibFile "mkDummySrc" {
          inherit (pkgs) writeText runCommandLocal lib;
          inherit writeTOML cleanCargoToml findCargoFiles;
        };

        mkCargoDerivation = importLibFile "mkCargoDerivation" ({
            cargo = cargoHostTarget;
            inherit (pkgs) stdenv lib;
          }
          // installHooks
          // otherHooks);
        buildDepsOnly = importLibFile "buildDepsOnly" {
          inherit
            mkCargoDerivation
            crateNameFromCargoToml
            vendorCargoDeps
            mkDummySrc
            ;
        };
        cargoBuild = importLibFile "cargoBuild" {
          inherit
            mkCargoDerivation
            buildDepsOnly
            crateNameFromCargoToml
            vendorCargoDeps
            ;
        };
        buildPackage = importLibFile "buildPackage" {
          inherit (pkgs) lib;
          inherit (installLogHook) installFromCargoBuildLogHook;
          inherit cargoBuild;
        };
      };
  };

  dreamOverrides = let
    overridesDirs =
      config.overridesDirs
      ++ (lib.optionals (b ? getEnv && b.getEnv "d2nOverridesDir" != "") [
        (b.getEnv "d2nOverridesDir")
      ]);
  in
    utils.loadOverridesDirs overridesDirs pkgs;

  # the location of the dream2nix framework for self references (update scripts, etc.)
  dream2nixWithExternals =
    if b.pathExists (./. + "/external")
    then ./.
    else
      pkgs.runCommand "dream2nix-full-src" {} ''
        cp -r ${./.} $out
        chmod +w $out
        mkdir $out/external
        cp -r ${externalDir}/* $out/external/
      '';

  # automatically find a suitable builder for a given dream lock
  findBuilder = dreamLock: let
    subsystem = dreamLock._generic.subsystem;
  in
    if ! subsystems."${subsystem}" ? builders
    then throw "Could not find any builder for subsystem '${subsystem}'"
    else subsystems."${subsystem}".builders.default;

  # detect if granular or combined fetching must be used
  findFetcher = dreamLock:
    if null != dreamLock._generic.sourcesAggregatedHash
    then fetchers.combinedFetcher
    else fetchers.defaultFetcher;

  # fetch only sources and do not build
  fetchSources = {
    dreamLock,
    sourceRoot ? null,
    fetcher ? null,
    extract ? false,
    sourceOverrides ? oldSources: {},
  } @ args: let
    # if dream lock is a file, read and parse it
    dreamLock' = (utils.readDreamLock {inherit dreamLock;}).lock;

    fetcher =
      if args.fetcher or null == null
      then findFetcher dreamLock'
      else args.fetcher;

    fetched = fetcher rec {
      inherit sourceOverrides sourceRoot;
      defaultPackage = dreamLock._generic.defaultPackage;
      defaultPackageVersion = dreamLock._generic.packages."${defaultPackage}";
      sources = dreamLock'.sources;
      sourcesAggregatedHash = dreamLock'._generic.sourcesAggregatedHash;
    };

    fetchedSources = fetched.fetchedSources;
  in
    fetched
    // {
      fetchedSources =
        if extract
        then
          lib.mapAttrs
          (key: source: utils.extractSource {inherit source;})
          fetchedSources
        else fetchedSources;
    };

  # build a dream lock via a specific builder
  callBuilder = {
    builder,
    builderArgs,
    fetchedSources,
    dreamLock,
    inject,
    sourceOverrides,
    packageOverrides,
    allOutputs,
  } @ args: let
    # inject dependencies
    dreamLock = utils.dreamLock.injectDependencies args.dreamLock inject;

    dreamLockInterface = (utils.readDreamLock {inherit dreamLock;}).interface;

    produceDerivation = name: pkg:
      utils.applyOverridesToPackage {
        inherit pkg;
        outputs = allOutputs;
        pname = name;
        conditionalOverrides = packageOverrides;
      };

    outputs = builder.build (builderArgs
      // {
        inherit
          produceDerivation
          dreamLock
          ;

        inherit
          (dreamLockInterface)
          subsystemAttrs
          getSourceSpec
          getRoot
          getDependencies
          getCyclicDependencies
          defaultPackageName
          defaultPackageVersion
          packages
          packageVersions
          ;

        getSource = utils.dreamLock.getSource fetchedSources;
      });

    # Makes the packages tree compatible with flakes schema.
    # For each package the attr `{pname}` will link to the latest release.
    # Other package versions will be inside: `{pname}.versions`
    # Adds a `default` package by using `defaultPackageName` and `defaultPackageVersion`.
    formattedOutputs =
      outputs
      // {
        packages = let
          allPackages = outputs.packages or {};

          latestPackages =
            lib.mapAttrs'
            (pname: releases: let
              latest =
                releases."${utils.latestVersion (b.attrNames releases)}";
            in (lib.nameValuePair
              "${pname}"
              (latest
                // {
                  versions = releases;
                })))
            allPackages;

          defaultPackage =
            allPackages
            ."${dreamLockInterface.defaultPackageName}"
            ."${dreamLockInterface.defaultPackageVersion}";
        in
          latestPackages // {default = defaultPackage;};
      };
  in
    formattedOutputs;

  riseAndShine = throw ''
    `riseAndShine` is deprecated. See usage in readme.md.
  '';

  makeOutputsForDreamLock = {
    dreamLock,
    sourceRoot ? null,
    fetcher ? null,
    builder ? null,
    builderArgs ? {},
    inject ? {},
    sourceOverrides ? oldSources: {},
    packageOverrides ? {},
  } @ args: let
    # parse dreamLock
    dreamLockLoaded = utils.readDreamLock {inherit (args) dreamLock;};
    dreamLock = dreamLockLoaded.lock;
    dreamLockInterface = dreamLockLoaded.interface;

    builder' =
      if builder == null
      then findBuilder dreamLock
      else if l.isString builder
      then subsystems.${dreamLock._generic.subsystem}.builders.${builder}
      else builder;

    fetcher' =
      if fetcher == null
      then findFetcher dreamLock
      else fetcher;

    fetchedSources =
      (fetchSources {
        inherit dreamLock sourceOverrides sourceRoot;
        fetcher = fetcher';
      })
      .fetchedSources;

    builderOutputs = callBuilder {
      inherit
        dreamLock
        fetchedSources
        allOutputs
        sourceOverrides
        ;

      builder = builder';

      inherit builderArgs;

      packageOverrides =
        lib.recursiveUpdate
        (dreamOverrides."${dreamLock._generic.subsystem}" or {})
        (args.packageOverrides or {});

      inject = args.inject or {};
    };

    allOutputs = builderOutputs;
  in
    allOutputs;

  translateProjects = {
    discoveredProjects ?
      dlib.discoverers.discoverProjects
      {inherit settings tree;},
    source ? throw "Pass either `source` or `tree` to translateProjects",
    tree ? dlib.prepareSourceTree {inherit source;},
    pname,
    settings ? [],
  } @ args: let
    getTranslator = subsystem: translatorName:
      subsystems."${subsystem}".translators."${translatorName}";

    isImpure = project: translatorName:
      (getTranslator project.subsystem translatorName).type == "impure";

    getInvalidationHash = project:
      dlib.calcInvalidationHash {
        inherit project source;
        # TODO: add translatorArgs
        translatorArgs = {};
        translator = project.translator;
      };

    isResolved = project: let
      dreamLockExists =
        l.pathExists "${config.projectRoot}/${project.dreamLockPath}";

      dreamLockValid =
        project.dreamLock._generic.invalidationHash
        or ""
        == project.invalidationHash;
    in
      dreamLockExists && dreamLockValid;

    getProjectKey = project: "${project.name}_|_${project.subsystem}_|_${project.relPath}";

    # list of projects extended with some information requried for processing
    projectsList =
      l.map
      (project: (let
        self =
          project
          // rec {
            dreamLock =
              (utils.readDreamLock {
                dreamLock = "${config.projectRoot}/${project.dreamLockPath}";
              })
              .lock;
            impure = isImpure project translator;
            invalidationHash = getInvalidationHash project;
            key = getProjectKey project;
            resolved = isResolved self;
            translator = project.translator or (l.head project.translators);
          };
      in
        self))
      discoveredProjects;

    # projects without existing valid dream-lock.json
    projectsPureUnresolved =
      l.filter
      (project: ! project.resolved && ! project.impure)
      projectsList;

    # already resolved projects
    projectsResolved =
      l.filter
      (project: project.resolved)
      projectsList;

    # list of pure projects extended with 'dreamLock' attribute
    projectsResolvedOnTheFly =
      l.forEach projectsPureUnresolved
      (proj: let
        translator = getTranslator proj.subsystem proj.translator;
        dreamLock'' = translator.translate {
          inherit source tree discoveredProjects;
          project = proj;
        };

        /*
         simpleTranslate2 exposes result via `.result` in order to allow for
         unit testing via `.inputs`.
         */
        dreamLock' = dreamLock''.result or dreamLock'';

        dreamLock =
          dreamLock'
          // {
            _generic =
              dreamLock'._generic
              // {
                invalidationHash = proj.invalidationHash;
              };
          };
      in
        proj
        // {
          inherit dreamLock;
        });

    resolvedProjects = projectsResolved ++ projectsResolvedOnTheFly;
  in
    resolvedProjects;

  # transform a list of resolved projects to buildable outputs
  realizeProjects = {
    inject ? {},
    translatedProjects ? translateProjects {inherit pname settings source;},
    # alternative way of calling (for debugging)
    pname ? null,
    source ? null,
    packageOverrides ? {},
    sourceOverrides ? oldSources: {},
    settings ? [],
  }: let
    dreamLocks = l.forEach translatedProjects (proj: proj.dreamLock);

    defaultSourceOverride = dreamLock:
      if source == null
      then {}
      else let
        defaultPackage = dreamLock._generic.defaultPackage;
        defaultPackageVersion =
          dreamLock._generic.packages."${defaultPackage}";
      in {
        "${defaultPackage}"."${defaultPackageVersion}" = "${source}/${dreamLock._generic.location}";
      };

    # extends each package with a `.resolve` attribute
    # and applies sourceOverrides
    outputsForProject = proj: let
      outputs = makeOutputsForDreamLock {
        inherit inject packageOverrides;
        sourceRoot = source;
        builder = proj.builder or null;
        dreamLock = proj.dreamLock;
        sourceOverrides = oldSources:
          dlib.recursiveUpdateUntilDepth
          1
          (defaultSourceOverride proj.dreamLock)
          (sourceOverrides oldSources);
      };
    in
      outputs
      // {
        packages =
          l.mapAttrs
          (pname: pkg:
            pkg.overrideAttrs (old: {
              passthru =
                old.passthru
                or {}
                // {
                  resolve = utils.makeTranslateScript {
                    inherit source;
                    invalidationHash = proj.invalidationHash;
                    project = proj;
                  };
                };
            }))
          (outputs.packages or {});
      };

    projectOutputs = l.map outputsForProject translatedProjects;

    mergedOutputs = let
      isNotDrvAttrs = val:
        l.isAttrs val && (val.type or "") != "derivation";
      recursiveUpdateUntilDrv =
        l.recursiveUpdateUntil
        (_: l: r: !(isNotDrvAttrs l && isNotDrvAttrs r));
    in
      l.foldl' recursiveUpdateUntilDrv {} projectOutputs;
  in
    mergedOutputs;

  generateImpureResolveScript = {
    source,
    impureDiscoveredProjects,
  }: let
    impureResolveScriptsList =
      l.listToAttrs
      (
        l.map
        (
          project:
            l.nameValuePair
            "Name: ${project.name}; Subsystem: ${project.subsystem}; relPath: ${project.relPath}"
            (utils.makeTranslateScript {inherit project source;})
        )
        impureDiscoveredProjects
      );

    resolveImpureScript =
      utils.writePureShellScriptBin
      "resolve"
      []
      ''
        cd $WORKDIR
        ${l.concatStringsSep "\n"
          (l.mapAttrsToList
            (title: script: ''
              echo "Resolving:: ${title}"
              ${script}/bin/resolve
            '')
            impureResolveScriptsList)}
      '';
  in
    resolveImpureScript;

  makeOutputs = {
    source ? throw "pass a 'source' to 'makeOutputs'",
    discoveredProjects ? dlib.discoverers.discoverProjects {inherit settings source;},
    pname ? null,
    settings ? [],
    packageOverrides ? {},
    sourceOverrides ? old: {},
    inject ? {},
  }: let
    impureDiscoveredProjects =
      l.filter
      (proj:
        subsystems
        ."${proj.subsystem}"
        .translators
        ."${proj.translator}"
        .type
        == "impure")
      discoveredProjects;

    resolveImpureScript = generateImpureResolveScript {
      inherit impureDiscoveredProjects source;
    };

    translatedProjects = translateProjects {
      inherit
        discoveredProjects
        pname
        settings
        source
        ;
    };

    realizedProjects = realizeProjects {
      inherit
        inject
        packageOverrides
        sourceOverrides
        translatedProjects
        source
        ;
    };

    impureFakeDerivations =
      l.listToAttrs
      (l.map
        (proj:
          l.nameValuePair
          proj.name
          rec {
            type = "derivation";
            name = proj.name;
            resolve = utils.makeTranslateScript {
              project = proj;
              inherit source;
            };
            drvPath = throw ''
              The ${proj.subsystem} package ${proj.name} contains unresolved impurities.
              Resolve by running the .resolve attribute of this derivation
              or by resolving all impure projects by running the `resolveImpure` package
            '';
          })
        impureDiscoveredProjects);
  in
    realizedProjects
    // {
      packages =
        l.warnIf
        (realizeProjects.packages.resolveImpure or null != null)
        ''
          a builder outputted a package named 'resolveImpure'
          this will be overridden by dream2nix!
        ''
        impureFakeDerivations
        // (realizedProjects.packages or {})
        // {resolveImpure = resolveImpureScript;};
    };
in {
  inherit
    apps
    callPackageDream
    dream2nixWithExternals
    fetchers
    indexers
    fetchSources
    realizeProjects
    translateProjects
    riseAndShine
    updaters
    utils
    makeOutputsForDreamLock
    makeOutputs
    subsystems
    ;
}
