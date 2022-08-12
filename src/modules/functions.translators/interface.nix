{config, ...}: let
  lib = config.lib;
  t = lib.types;
in {
  options.functions.translators = {
    makeTranslatorDefaultArgs = lib.mkOption {type = t.functionTo t.anything;};
  };
}
