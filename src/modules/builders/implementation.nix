{
  config,
  callPackageDream,
  lib,
  ...
}: let
  defaults = {
    rust = "build-rust-package";
    nodejs = "granular-nodejs";
    python = "simple-python";
    php = "granular-php";
  };
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

    buildersBySubsystem =
      lib.mapAttrs
      (
        subsystem: builders:
          builders
          // lib.optionalAttrs (lib.hasAttr subsystem defaults) {
            default = builders.${defaults.${subsystem}};
          }
      )
      (funcs.structureBySubsystem config.builderInstances);
  };
}
