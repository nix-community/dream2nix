{
  config,
  callPackageDream,
  lib,
  ...
}: let
  funcs = config.functions.subsystem-loading;
  collectedModules = funcs.collect "discoverers";
in {
  config = {
    # The user can add more discoverers by extending this attribute
    discoverers = funcs.import_ collectedModules;

    discoverersBySubsystem = funcs.structureBySubsystem config.discoverers;
  };
}
