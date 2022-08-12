{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # TODO
  validator = module: true;

  modules = dlib.modules.makeSubsystemModules {
    inherit validator;
    modulesCategory = "translators";
  };

  translators =
    dlib.modules.mapSubsystemModules
    (t:
      t
      // (lib.optionalAttrs (t.translate or null != null) {
        translate = l.trace t dlib.warnIfIfd t t.translate;
      }))
    modules.modules;
  mapTranslators = f: dlib.modules.mapSubsystemModules f translators;
in {
  inherit translators mapTranslators;
  callTranslator = modules.callModule;

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
