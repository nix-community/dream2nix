{
  dlib,
  lib,
}: let
  l = lib // builtins;

  validateExtraModules = f: extra:
    l.foldl'
    (acc: el: l.seq (f el) acc)
    {}
    extra;
  validateExtraModule = extra:
    true;

  makeSubsystemModules = {
    modulesCategory,
    validator,
    extraModules ? [],
  }: let
    callModule = {
      subsystem,
      name,
      file,
      ...
    } @ args: let
      filteredArgs = l.removeAttrs args ["subsystem" "name"];
      module = dlib.modules.importModule (filteredArgs
        // {
          validate = validator;
        });
    in
      module // {inherit subsystem name;};

    _extraModules =
      l.seq
      (validateExtraModules validateExtraModule extraModules)
      extraModules;

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
            (name:
              callModule {
                inherit subsystem name;
                file = ../subsystems + "/${subsystem}/${modulesCategory}/${name}";
              });
        in
          l.filterAttrs
          (name: t: t.disabled or false == false)
          modulesLoaded
      );
    modulesExtended =
      l.foldl'
      (
        acc: el:
          l.recursiveUpdate
          acc
          {"${el.subsytem}"."${el.name}" = callModule el;}
      )
      modules
      extraModules;

    mapModules = f:
      l.mapAttrs
      (
        subsystem: names:
          l.mapAttrs
          (name: module: f module)
          names
      )
      modulesExtended;
  in {
    modules = modulesExtended;
    inherit
      callModule
      mapModules
      ;
  };
in {
  inherit
    makeSubsystemModules
    validateExtraModules
    ;
}
