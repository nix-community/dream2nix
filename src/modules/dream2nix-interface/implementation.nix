{config, ...}: let
  l = config.lib;
  b = builtins;

  inherit (config) dream2nixConfig pkgs utils dlib lib;

  dreamOverrides = let
    overridesDirs =
      config.dream2nixConfig.overridesDirs
      ++ (lib.optionals (b ? getEnv && b.getEnv "d2nOverridesDir" != "") [
        (b.getEnv "d2nOverridesDir")
      ]);
  in
    utils.loadOverridesDirs overridesDirs pkgs;

  # automatically find a suitable builder for a given dream lock
  findBuilder = dreamLock: let
    subsystem = dreamLock._generic.subsystem;
  in
    if ! config.buildersBySubsystem ? ${subsystem}
    then throw "Could not find any builder for subsystem '${subsystem}'"
    else config.buildersBySubsystem.${subsystem}.default;

  # detect if granular or combined fetching must be used
  findFetcher = dreamLock:
    if null != dreamLock._generic.sourcesAggregatedHash or null
    then config.functions.combinedFetcher
    else config.functions.defaultFetcher;

  # fetch only sources and do not build
  fetchSources = {
    dreamLock,
    sourceRoot ? null,
    fetcher ? null,
    extract ? false,
    sourceOverrides ? oldSources: {},
  } @ args: let
    # if dream lock is a file, read and parse it
    dreamLock' = (utils.dream-lock.readDreamLock {inherit dreamLock;}).lock;

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
    sourceRoot,
    dreamLock,
    inject,
    sourceOverrides,
    packageOverrides,
    allOutputs,
  } @ args: let
    # inject dependencies
    dreamLock = utils.dream-lock.injectDependencies args.dreamLock inject;

    dreamLockInterface = (utils.dream-lock.readDreamLock {inherit dreamLock;}).interface;

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
          dreamLock
          pkgs
          produceDerivation
          sourceRoot
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

        getSource = utils.dream-lock.getSource fetchedSources;
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
                releases."${dlib.latestVersion (b.attrNames releases)}";
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
    dreamLockLoaded = utils.dream-lock.readDreamLock {inherit (args) dreamLock;};
    dreamLock = dreamLockLoaded.lock;
    dreamLockInterface = dreamLockLoaded.interface;

    builder' =
      if builder == null
      then findBuilder dreamLock
      else if l.isString builder
      then config.buildersBySubsystem.${dreamLock._generic.subsystem}.${builder}
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
        sourceRoot
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
      config.functions.discoverers.discoverProjects
      {inherit settings tree;},
    projects ? {},
    source ? throw "Pass either `source` or `tree` to translateProjects",
    tree ? dlib.prepareSourceTree {inherit source;},
    pname,
    settings ? [],
  } @ args: let
    getTranslator = translatorName:
      config.translators.${translatorName};

    isImpure = project: translatorName:
      (getTranslator translatorName).type == "impure";

    getInvalidationHash = project:
      dlib.calcInvalidationHash {
        inherit project source;
        # TODO: add translatorArgs
        translatorArgs = {};
        translator = project.translator;
        config = dream2nixConfig;
      };

    isResolved = project: let
      dreamLockExists =
        l.pathExists "${toString dream2nixConfig.projectRoot}/${project.dreamLockPath}";

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
              (utils.dream-lock.readDreamLock {
                dreamLock = "${toString dream2nixConfig.projectRoot}/${project.dreamLockPath}";
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
        translator = getTranslator proj.translator;
        dreamLock'' = translator.finalTranslate {
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
  in
    dlib.mergeFlakes projectOutputs;

  generateImpureResolveScript = {
    source,
    impureProjects,
  }: let
    impureResolveScriptsList =
      l.listToAttrs
      (
        l.map
        (
          project:
            l.nameValuePair
            "Name: ${project.name}; Subsystem: ${project.subsystem or "?"}; relPath: ${project.relPath}"
            (utils.makeTranslateScript {inherit project source;})
        )
        impureProjects
      );

    resolveImpureScript =
      utils.writePureShellScriptBin
      "resolve"
      []
      ''
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
    discoveredProjects ?
      config.functions.discoverers.discoverProjects {
        inherit settings source;
      },
    pname ? null,
    projects ? {},
    settings ? [],
    packageOverrides ? {},
    sourceOverrides ? old: {},
    inject ? {},
  }: let
    # if projects are defined manually, ignore discoveredProjects
    finalProjects =
      if projects != {}
      then let
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
              config.functions.discoverers.getDreamLockPath
              proj
              (l.head projectsList);
          })
      else discoveredProjects;

    impureProjects =
      l.filter
      (proj:
        config.translators."${proj.translator}".type
        == "impure")
      finalProjects;

    resolveImpureScript = generateImpureResolveScript {
      inherit impureProjects source;
    };

    translatedProjects = translateProjects {
      discoveredProjects = finalProjects;
      inherit
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
          {
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
        impureProjects);
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
  config.dream2nix-interface = {
    inherit
      fetchSources
      realizeProjects
      translateProjects
      makeOutputsForDreamLock
      makeOutputs
      ;
  };
}
