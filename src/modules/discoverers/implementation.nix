{config, ...}: let
  funcs = config.functions.subsystem-loading;
  collectedModules = funcs.collect "discoverers";
in {
  config = {
    discoverers = funcs.import_ collectedModules;

    discoverersBySubsystem = funcs.structureBySubsystem config.discoverers;
  };
}
