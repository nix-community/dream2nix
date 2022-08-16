{config, ...}: let
  lib = config.lib;

  # pupulates a translators special args with defaults
  makeTranslatorDefaultArgs = extraArgsDef:
    lib.mapAttrs
    (
      name: def:
        if def.type == "flag"
        then false
        else def.default or null
    )
    extraArgsDef;
in {
  functions.translators = {
    inherit
      makeTranslatorDefaultArgs
      ;
  };
}
