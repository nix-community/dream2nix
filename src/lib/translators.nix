{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # INTERNAL

  subsystems = dlib.dirNames ../translators;

  translatorTypes = ["impure" "ifd" "pure"];

  # attrset of: subsystem -> translator-type -> (function subsystem translator-type)
  mkTranslatorsSet = function:
    l.genAttrs
    (dlib.dirNames ../translators)
    (subsystem: let
      availableTypes =
        l.filter
        (type: l.pathExists (../translators + "/${subsystem}/${type}"))
        translatorTypes;

      translatorsForTypes =
        l.genAttrs
        availableTypes
        (transType: function subsystem transType);
    in
      translatorsForTypes
      // {
        all =
          l.foldl'
          (a: b: a // b)
          {}
          (l.attrValues translatorsForTypes);
      });

  # flat list of all translators sorted by priority (pure translators first)
  translatorsList = let
    list = l.collect (v: v ? subsystem) translators;
    prio = translator:
      if translator.type == "pure"
      then 0
      else if translator.type == "ifd"
      then 1
      else if translator.type == "impure"
      then 2
      else 3;
  in
    l.sort
    (a: b: (prio a) < (prio b))
    list;

  callTranslator = subsystem: type: name: file: args: let
    translatorModule = import file {
      inherit dlib lib;
    };
  in
    translatorModule
    // {
      inherit name subsystem type;
    };

  # EXPORTED

  # attrset of: subsystem -> translator-type -> translator
  translators = mkTranslatorsSet (
    subsystem: type: let
      translatorNames =
        dlib.dirNames (../translators + "/${subsystem}/${type}");

      translatorsLoaded =
        l.genAttrs
        translatorNames
        (translatorName:
          callTranslator
          subsystem
          type
          translatorName
          (../translators + "/${subsystem}/${type}/${translatorName}")
          {});
    in
      l.filterAttrs
      (name: t: t.disabled or false == false)
      translatorsLoaded
  );

  mapTranslators = f:
    l.mapAttrs
    (subsystem: types:
      l.mapAttrs
      (type: names:
        l.mapAttrs
        (name: translator: f translator)
        names)
      types)
    translators;

  # pupulates a translators special args with defaults
  getextraArgsDefaults = extraArgsDef:
    l.mapAttrs
    (
      name: def:
        if def.type == "flag"
        then false
        else def.default or null
    )
    extraArgsDef;
in {
  inherit
    getextraArgsDefaults
    mapTranslators
    translators
    ;
}
