{config, ...}: let
  funcs = import ../subsystem-loading.nix config;
  collectedModules = funcs.collect "discoverers";
in {
  config = {
    discoverers = funcs.import_ collectedModules;

    discoverersBySubsystem = funcs.structureBySubsystem (
      # remove the "default" discoverer we create, as it's not subsystem specific.
      builtins.removeAttrs config.discoverers ["default"]
    );
  };
}
