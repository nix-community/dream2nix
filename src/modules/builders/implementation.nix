{config, ...}: let
  lib = config.lib;
  defaults = {
    rust = "build-rust-package";
    nodejs = "granular-nodejs";
    python = "simple-python";
    php = "granular-php";
    haskell = "simple-haskell";
    debian = "simple-debian";
    racket = "simple-racket";
  };
  funcs = config.functions.subsystem-loading;
  collectedModules = funcs.collect "builders";
in {
  config = {
    # The user can add more translators by extending this attribute
    builders = funcs.import_ collectedModules;

    buildersBySubsystem =
      lib.mapAttrs
      (
        subsystem: builders:
          builders
          // lib.optionalAttrs (lib.hasAttr subsystem defaults) {
            default = builders.${defaults.${subsystem}};
          }
      )
      (funcs.structureBySubsystem config.builders);
  };
}
