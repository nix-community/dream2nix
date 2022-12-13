{config, ...}: let
  l = config.lib // builtins;
  dlib = config.dlib;

  /*
  Stripped down discoverProjects without settings merging and dreamLockPath
    represented as an attrset:
    {
      ${project-name} = {
        relPath = ...;
        subsystem = ...;
        subsystemInfo = {
          ...
        };
        translator = "some-translator";

        # all compatible translators
        translators = [
          "some-translator"
          "some-alternative-translator"
        ];
      }
    }
  */
  discoverProjects2 = {
    source ? throw "Pass either `source` or `tree` to discoverProjects",
    tree ? dlib.prepareSourceTree {inherit source;},
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

    allProjects = discoveredProjectsSorted;

    projectsExtended =
      l.forEach allProjects
      (proj:
        proj
        // {
          relPath = proj.relPath or "";
          translator = proj.translator or (l.head proj.translators);
        });
  in
    l.listToAttrs (
      l.map
      (proj: l.nameValuePair proj.name proj)
      projectsExtended
    );

  /*
  legacy function doing some custom merging on `settings`.
  We should remove that function once there is no more usage within the
    frameworks code.
  */
  discoverProjects = {
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

    allProjects = discoveredProjectsSorted;

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
      discoverProjects2
      getDreamLockPath
      applyProjectSettings
      ;
  };
}
