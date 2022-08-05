{
  config,
  lib,
  ...
}: let
  t = lib.types;
in {
  imports = [
    ./translators.nix
  ];
  options = {
    lib = lib.mkOption {
      type = t.anything;
    };
    translatorModules = lib.mkOption {
      type = t.attrsOf (t.submodule ./interfaces/translator.nix);
      description = ''
        Translator module definitions
      '';
    };
    translators = lib.mkOption {
      type = t.anything;
    };
  };
  config = {
    lib = lib // builtins;
  };
}
