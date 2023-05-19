{lib, ...}: let
  l = builtins // lib;

  mkDiscovereredProject = {
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

  mkPathSource = {
    path,
    rootName,
    rootVersion,
  } @ args:
    args
    // {
      type = "path";
    };
in {
  inherit
    mkDiscovereredProject
    mkPathSource
    ;
}
