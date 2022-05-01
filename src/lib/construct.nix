# constructors to have at least some kind of `type` safety
{
  config,
  lib,
}: {
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
}
