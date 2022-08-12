{
  config,
  callPackageDream,
  ...
}: let
  lib = config.lib;
  t = lib.types;
  # TODO: the makeTranslator logic should be moved somewhere to /src/modules
  loader = (callPackageDream ../../subsystems/translators.nix {}).makeTranslator;
  funcs = config.functions.subsystem-loading;
  collectedModules = funcs.collect "translators";
in {
  config = {
    # The user can add more translators by extending this attribute
    translators = funcs.import_ collectedModules;

    /*
    translators wrapped with extra logic to add extra attributes,
    like .translateBin for pure translators
    */
    translatorInstances = funcs.instantiate config.translators loader;

    translatorsBySubsystem = funcs.structureBySubsystem config.translatorInstances;
  };
}
