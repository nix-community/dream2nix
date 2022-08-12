{
  config,
  lib,
  ...
}: let
  t = lib.types;
in {
  options = {
    translators = lib.mkOption {
      type = t.attrsOf (t.submodule ./interface-translator.nix);
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
