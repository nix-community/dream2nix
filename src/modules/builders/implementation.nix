{config, ...}: let
  l = config.lib;
  defaults = {
    # TODO: define a priority in each builder and remove the defaults here.
    rust = "build-rust-package";
    nodejs = "granular-nodejs";
    python = "simple-python";
    php = "granular-php";
    haskell = "simple-haskell";
    debian = "simple-debian";
    racket = "simple-racket";
  };
  funcs = import ../subsystem-loading.nix config;
  collectedModules = funcs.collect "builders";
in {
  config = {
    # The user can add more translators by extending this attribute
    builders = funcs.import_ collectedModules;

    buildersBySubsystem =
      l.mapAttrs
      (
        subsystem: builders:
          builders
          // {
            default =
              if l.hasAttr subsystem defaults
              then builders.${defaults.${subsystem}}
              else l.head (l.attrValues builders);
          }
      )
      (funcs.structureBySubsystem config.builders);
  };
}
