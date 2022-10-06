{config, ...}: let
  funcs = import ../subsystem-loading.nix config;
  collectedModules = funcs.collect "discoverers";
in {
  config = {
    discoverers = funcs.import_ collectedModules;

    discoverersBySubsystem = funcs.structureBySubsystem config.discoverers;
  };
}
