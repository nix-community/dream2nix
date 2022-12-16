{config, ...}: let
  l = config.lib;
in {
  config.dlib.construct = {
    discoveredProject = {
      name,
      relPath,
      subsystem,
      subsystemInfo,
      translators,
    }: {
      inherit
        name
        relPath
        subsystem
        subsystemInfo
        translators
        ;
    };

    pathSource = {
      path,
      rootName,
      rootVersion,
    } @ args:
      args
      // {
        type = "path";
      };
  };
}
