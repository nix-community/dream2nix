{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # TODO
  validator = module: {
    success = true;
  };

  modules = dlib.makeSubsystemModules {
    inherit validator;
    modulesCategory = "translators";
  };
in {
  callTranslator = modules.callModule;
  mapTranslators = modules.mapModules;
  translators = modules.modules;

  # pupulates a translators special args with defaults
  getextraArgsDefaults = extraArgsDef:
    l.mapAttrs
    (
      name: def:
        if def.type == "flag"
        then false
        else def.default or null
    )
    extraArgsDef;
}
