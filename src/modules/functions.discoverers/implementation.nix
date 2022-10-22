{config, ...}: let
  l = config.lib // builtins;
  dlib = config.dlib;

  discoverProjects = {
    projects,
    source ? throw "Pass either `source` or `tree` to discoverProjects",
    tree ? dlib.prepareSourceTree {inherit source;},
    settings ? [],
  }: let
    discoveredProjects =
      l.flatten
      (
        l.map
        (discoverer: discoverer.discover {inherit tree;})
        (l.attrValues config.discoverers)
      );

    discoveredProjectsSorted = let
      sorted =
        l.sort
        (p1: p2: l.hasPrefix p1.relPath or "" p2.relPath or "")
        discoveredProjects;
    in
      sorted;

    allProjects = discoveredProjectsSorted ++ (l.attrValues projects);

    rootProject = l.head allProjects;

    projectsExtended =
      l.forEach allProjects
      (proj:
        proj
        // {
          relPath = proj.relPath or "";
          translator = proj.translator or (l.head proj.translators);
          dreamLockPath = getDreamLockPath proj rootProject;
        });
  in
    applyProjectSettings projectsExtended settings;

  getDreamLockPath = project: rootProject:
    dlib.sanitizeRelativePath
    "${config.dream2nixConfig.packagesDir}/${rootProject.name}/${project.relPath or ""}/dream-lock.json";

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
      l.forEach projects (proj: applyAllSettings proj);
  in
    settingsApplied;
in {
  functions.discoverers = {
    inherit
      discoverProjects
      getDreamLockPath
      applyProjectSettings
      ;
  };
}
