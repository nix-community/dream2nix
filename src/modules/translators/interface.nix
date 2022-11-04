{config, ...}: let
  lib = config.lib;
  t = lib.types;
in {
  options = {
    translators = lib.mkOption {
      type = t.lazyAttrsOf (t.submoduleWith {
        modules = [../interfaces.translator];
        specialArgs = {framework = config;};
      });
      description = ''
        Translator module definitions
      '';
    };
    translatorsBySubsystem = lib.mkOption {
      type = t.attrsOf (t.attrsOf t.anything);
    };
  };
}
