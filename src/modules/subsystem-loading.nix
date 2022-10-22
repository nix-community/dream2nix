/*
Generic logic to load subsystem specific module implementations like those for
translators and builders.

This recurses through the following directory structure to discover and load
modules:
  /src/subsystems/{subsystem}/{module-type}/{module-name}

This is not included in `config.functions` because it causes infinite recursion.
*/
config: let
  inherit (config) dlib lib;
  subsystemsDir = lib.toString ../subsystems;
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
    (
      name: description: let
        attrs = {inherit (description) name subsystem;};
      in
        (import description.path (config // attrs)) // attrs
    )
    (
      lib.foldl'
      (
        all: el:
          if lib.hasAttr el.name all
          then
            throw ''
              module named ${el.name} in subsystem ${el.value.subsystem} conflicts
              with a module with the same name from subsystem ${all.${el.name}.subsystem}
            ''
          else all // {${el.name} = el.value;}
      )
      {}
      collectedModules
    );

  structureBySubsystem = instances:
    lib.foldl
    lib.recursiveUpdate
    {}
    (lib.mapAttrsToList
      (tName: t: {"${t.subsystem}"."${tName}" = t;})
      instances);
in {
  inherit
    collect
    import_
    structureBySubsystem
    ;
}
