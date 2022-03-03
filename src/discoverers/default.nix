{
  dlib,
  lib,
}:

let
  l = lib // builtins;

  subsystems = dlib.dirNames ./.;

  allDiscoverers =
    l.collect
      (v: v ? discover)
      discoverers;

  discoverProjects =
    {
      source ? throw "Pass either `source` or `tree` to discoverProjects",
      tree ? dlib.prepareSourceTree { inherit source; },
      settings ? [],
    }: let
      discovered =
        l.flatten
          (l.map
            (discoverer: discoverer.discover { inherit tree; })
            allDiscoverers);
    in
      applyProjectSettings discovered settings;

  applyProjectSettings = projects: settingsList:
    let
      settingsListForProject = project:
        l.filter
          (settings:
            if ! settings ? filter then true
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

    in settingsApplied;


  discoverers = l.genAttrs subsystems (subsystem:
    (import (./. + "/${subsystem}") { inherit dlib lib subsystem; })
  );
in

{
  inherit
    applyProjectSettings
    discoverProjects
    discoverers
  ;
}
