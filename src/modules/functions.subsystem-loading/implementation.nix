/*
Generic logic to load subsystem specific module implementations like those for
translators and builders.

This recurses through the following directory structure to discover and load
modules:
  /src/subsystems/{subsystem}/{module-type}/{module-name}
*/
{
  config,
  dlib,
  callPackageDream,
  ...
}: let
  lib = config.lib;
  t = lib.types;
  subsystemsDir = lib.toString ../../subsystems;
  subsystems = dlib.dirNames subsystemsDir;

  collect = moduleDirName:
    lib.concatMap
    (subsystem: let
      dir = "${subsystemsDir}/${subsystem}/${moduleDirName}";
      exists = lib.pathExists dir;
      names = dlib.dirNames dir;
    in
      if ! exists
      then []
      else
        lib.map
        (name:
          lib.nameValuePair
          name
          # description of the module
          {
            inherit subsystem name;
            path = subsystemsDir + "/${subsystem}/${moduleDirName}/${name}";
          })
        names)
    subsystems;

  import_ = collectedModules:
    lib.mapAttrs
    (name: description:
      (import description.path {inherit dlib lib;})
      // {inherit (description) name subsystem;})
    (lib.listToAttrs collectedModules);

  instantiate = importedModules: loader:
    lib.mapAttrs
    (name: module:
      (loader module)
      // {inherit (module) name subsystem;})
    importedModules;

  structureBySubsystem = instances:
    lib.foldl
    lib.recursiveUpdate
    {}
    (lib.mapAttrsToList
      (tName: t: {"${t.subsystem}"."${tName}" = t;})
      instances);
in {
  /*
  Expose the functions via via the modules system.
  */
  config.functions.subsystem-loading = {
    inherit
      collect
      import_
      instantiate
      structureBySubsystem
      ;
  };
}
