{
  config,
  callPackageDream,
  ...
}: let
  loader = b: b // {build = callPackageDream b.build {};};
  funcs = config.functions.subsystem-loading;
  collectedModules = funcs.collect "builders";
in {
  config = {
    # The user can add more translators by extending this attribute
    builders = funcs.import_ collectedModules;

    /*
    translators wrapped with extra logic to add extra attributes,
    like .translateBin for pure translators
    */
    builderInstances = funcs.instantiate config.builders loader;

    buildersBySubsystem = funcs.structureBySubsystem config.builderInstances;
  };
}
