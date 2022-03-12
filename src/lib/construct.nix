# constructors to have at least some kind of `type` safety
{lib}: {
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
}
