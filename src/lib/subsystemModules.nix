{
  dlib,
  lib,
}: let
  l = lib // builtins;

  makeSubsystemModules = {
    modulesCategory,
    validator,
  }: let
    callModule = {
      subsystem,
      name,
      # this should point to a module module file.
      # this can be used to import your own modules.
      file ? null,
      ...
    } @ args: let
      file = args.file or (../subsystems + "/${subsystem}/${modulesCategory}/${name}");
      filteredArgs = l.removeAttrs args ["subsystem" "name"];
      module = dlib.modules.importModule (filteredArgs
        // {
          inherit file;
          validate = validator;
        });
    in
      module // {inherit subsystem name;};

    modules =
      l.genAttrs
      dlib.subsystems
      (
        subsystem: let
          moduleNames =
            dlib.dirNames (../subsystems + "/${subsystem}/${modulesCategory}");

          modulesLoaded =
            l.genAttrs
            moduleNames
            (name: callModule {inherit subsystem name;});
        in
          l.filterAttrs
          (name: t: t.disabled or false == false)
          modulesLoaded
      );

    mapModules = f:
      l.mapAttrs
      (
        subsystem: names:
          l.mapAttrs
          (name: module: f module)
          names
      )
      modules;
  in {
    inherit
      callModule
      modules
      mapModules
      ;
  };
in {
  inherit makeSubsystemModules;
}
