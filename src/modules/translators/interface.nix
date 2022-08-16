{
  config,
  lib,
  specialArgs,
  ...
}: let
  t = lib.types;
in {
  options = {
    translators = lib.mkOption {
      type = t.attrsOf (t.submoduleWith {
        modules = [./interface-translator.nix];
        inherit specialArgs;
      });
      description = ''
        Translator module definitions
      '';
    };
    translatorInstances = lib.mkOption {
      type = t.attrsOf t.anything;
    };
    translatorsBySubsystem = lib.mkOption {
      type = t.attrsOf (t.attrsOf t.anything);
    };
  };
}
