{config, ...}: let
  lib = config.lib;
  t = lib.types;
in {
  options = {
    builders = lib.mkOption {
      type = t.lazyAttrsOf (t.submoduleWith {
        modules = [../interfaces.builder];
        specialArgs = {framework = config;};
      });
      description = ''
        builder module definitions
      '';
    };
    buildersBySubsystem = lib.mkOption {
      type = t.attrsOf (t.attrsOf t.anything);
    };
  };
}
