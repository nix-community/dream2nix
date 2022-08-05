{
  config,
  dlib,
  callPackageDream,
  ...
}: let
  lib = config.lib;
  t = lib.types;
  subsystemsDir = lib.toString ../subsystems;
  subsystems = dlib.dirNames subsystemsDir;

  translatorModulesCollected =
    lib.concatMap
    (subsystem: let
      translatorsDir = "${subsystemsDir}/${subsystem}/translators";
      exists = lib.pathExists translatorsDir;
      translatorNames = dlib.dirNames translatorsDir;
    in
      if ! exists
      then []
      else
        lib.map
        (translatorName:
          lib.nameValuePair
          translatorName
          (subsystemsDir + "/${subsystem}/translators/${translatorName}"))
        translatorNames)
    subsystems;

  # wrapa a translator
  # add impure translation script to pure translators
  # add default args to translator
  makeTranslator =
    (callPackageDream ../subsystems/translators.nix {}).makeTranslator;
in {
  config = {
    translatorModules =
      lib.mapAttrs
      (translatorName: path: import path {inherit dlib lib;})
      (lib.listToAttrs translatorModulesCollected);

    translators =
      lib.mapAttrs
      (translatorName: translatorRaw: makeTranslator translatorRaw)
      config.translatorModules;
  };
}
