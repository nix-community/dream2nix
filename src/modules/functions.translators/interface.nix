{config, ...}: let
  lib = config.lib;
  t = lib.types;
in {
  options.functions.translators = {
    makeTranslatorDefaultArgs = lib.mkOption {
      type = t.uniq (t.functionTo t.attrs);
    };
    wrapPureTranslator = lib.mkOption {
      type = t.uniq (t.functionTo t.package);
    };
  };
}
