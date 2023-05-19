# This is currently only used for legacy modules ported to v1.
# The dream-lock concept might be deprecated together with this module at some
#   point.
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
