{
  dlib,
  lib,
  config,
}: let
  l = lib // builtins;

  allDiscoverers =
    (dlib.modules.collectSubsystemModules modules.modules)
    ++ [defaultDiscoverer];

  allTranslators =
    dlib.modules.collectSubsystemModules dlib.translators.translators;

  translatorsWithDiscoverFunc =
    l.filter (translator: translator ? discoverProject) allTranslators;

  defaultDiscoverer.discover = {
    tree,
    dirName ? tree.relPath,
  }: let
    translatorsCurrentDir =
      l.filter
      (t: t.discoverProject tree)
      translatorsWithDiscoverFunc;

    projectsCurrentDir =
      l.map
      (t: {
        name = "${dirName}-${t.name}";
        relPath = tree.relPath;
        translators = [t.name];
        subsystem = t.subsystem;
      })
      translatorsCurrentDir;

    subdirProjects =
      l.flatten
      (l.mapAttrsToList
        (dirName: tree:
          defaultDiscoverer.discover {
            inherit dirName tree;
          })
        tree.directories or {});
  in
    if translatorsCurrentDir == []
    then subdirProjects
    else projectsCurrentDir ++ subdirProjects;

  discoverProjects = {
    source ? throw "Pass either `source` or `tree` to discoverProjects",
    tree ? dlib.prepareSourceTree {inherit source;},
    settings ? [],
  }: let
    discoveredProjects =
      l.flatten
      (l.map
        (discoverer: discoverer.discover {inherit tree;})
        allDiscoverers);

    discoveredProjectsSorted = let
      toposorted =
        l.toposort
        (p1: p2: l.hasPrefix p1.relPath p2.relPath)
        discoveredProjects;
    in
      toposorted.result;

    rootProject = l.head discoveredProjectsSorted;

    projectsExtended =
      l.forEach discoveredProjectsSorted
      (proj:
        proj
        // {
          translator = l.head proj.translators;
          dreamLockPath = getDreamLockPath proj rootProject;
        });
  in
    applyProjectSettings projectsExtended settings;

  getDreamLockPath = project: rootProject:
    dlib.sanitizeRelativePath
    "${config.packagesDir}/${rootProject.name}/${project.relPath}/dream-lock.json";

  applyProjectSettings = projects: settingsList: let
    settingsListForProject = project:
      l.filter
      (settings:
        if ! settings ? filter
        then true
        else settings.filter project)
      settingsList;

    applySettings = project: settings:
      l.recursiveUpdate project settings;

    applyAllSettings = project:
      l.foldl'
      (proj: settings: applySettings proj settings)
      project
      (settingsListForProject project);

    settingsApplied =
      l.forEach projects
      (proj: applyAllSettings proj);
  in
    settingsApplied;

  # TODO
  validator = module: true;

  modules = dlib.modules.makeSubsystemModules {
    modulesCategory = "discoverers";
    inherit validator;
  };
in {
  inherit
    applyProjectSettings
    discoverProjects
    ;

  discoverers = modules.modules;
  callDiscoverer = modules.callModule;
  mapDiscoverers = modules.mapModules;
}
