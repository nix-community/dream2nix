{config, ...}: let
  lib = config.lib;
  t = lib.types;
in {
  options = {
    discoverers = lib.mkOption {
      type = t.lazyAttrsOf (t.submoduleWith {
        modules = [../interfaces.discoverer];
        specialArgs = {framework = config;};
      });
      description = ''
        discoverer module definitions
      '';
    };
    discoverersBySubsystem = lib.mkOption {
      type = t.attrsOf (t.attrsOf t.anything);
    };
  };
}
