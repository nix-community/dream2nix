{config, ...}: let
  l = config.lib;

  translatorsWithDiscoverFunc =
    l.filter
    (translator: translator.discoverProject or null != null)
    (l.attrValues config.translators);

  defaultDiscoverer.discover = {tree}: let
    translatorsCurrentDir =
      l.filter
      (t: t.discoverProject tree)
      translatorsWithDiscoverFunc;

    projectsCurrentDir =
      l.map
      (t: {
        name = "main";
        relPath = tree.relPath;
        translators = [t.name];
        subsystem = t.subsystem;
      })
      translatorsCurrentDir;

    # If there are multiple projects detected for the same subsystem,
    # merge them to a single one with translators = [...]
    projectsCurrentDirMerged =
      l.attrValues
      (l.foldl
        (all: curr:
          all
          // {
            "${curr.subsystem}" =
              all.${curr.subsystem}
              or curr
              // {
                translators =
                  l.unique (all.${curr.subsystem}.translators or [] ++ curr.translators);
              };
          })
        {}
        projectsCurrentDir);

    subdirProjects =
      l.flatten
      (l.mapAttrsToList
        (dirName: tree:
          defaultDiscoverer.discover {
            inherit tree;
          })
        tree.directories or {});
  in (
    if translatorsCurrentDir == []
    then subdirProjects
    else projectsCurrentDirMerged ++ subdirProjects
  );
in {
  config = {
    discoverers.default = defaultDiscoverer;
  };
}
