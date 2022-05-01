{
  config,
  dlib,
  lib,
  ...
} @ args: let
  l = lib // builtins;

  allDiscoverers =
    l.collect
    (v: v ? discover)
    discoverers;

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

  getDreamLockPath = project: rootProject: let
    root =
      if config.projectRoot == null
      then "."
      else config.projectRoot;
  in
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

  makeDiscoverer = (name: subsystem:
    let
      constructor = (     if l.isPath subsystem     then (import subsystem)
                     else if l.isFunction subsystem then subsystem
                     else throw "Discoverer can be a path or a function, but instead was ${l.typeOf subsystem}");
      discoverer  = constructor { inherit dlib lib; subsystem = name; }; 
    in
      discoverer
  );

  subsystems = (l.genAttrs (dlib.dirNames ./.) (subsystem: ./. + "/${subsystem}"))
    // (config.discoverers or {});

  discoverers = l.mapAttrs makeDiscoverer subsystems;

  # discoverers = if subsystems ? ruby
  #   then l.mapAttrs makeDiscoverer subsystems
  #   else let _ = l.traceValSeq config; in throw "WTF MATE";
in {
  inherit
    applyProjectSettings
    discoverProjects
    discoverers
    ;
}
