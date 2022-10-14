{config, ...}: let
  funcs = import ../subsystem-loading.nix config;
  collectedModules = funcs.collect "translators";
in {
  config = {
    # The user can add more translators by extending this attribute
    translators = funcs.import_ collectedModules;

    translatorsBySubsystem = funcs.structureBySubsystem config.translators;
  };
}
