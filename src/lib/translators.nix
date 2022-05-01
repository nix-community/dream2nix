{
  config,
  dlib,
  lib,
  translators,
}: let
  l = lib // builtins;

  # INTERNAL

  # subsystems = (l.genAttrs (dlib.dirNames ../translators) (subsystem: ../translators + "/${subsystem}"))
  #   // (config.translators or {});

  translatorTypes = ["impure" "ifd" "pure"];

  # attrset of: subsystem -> translator-type -> (function subsystem translator-type)
  mkTranslatorsSet = function:
    l.mapAttrs
    (subsystemName: subsystem: let
      availableTypes =
        l.filter
        (type:
          if l.isPath subsystem
          then (l.pathExists "${subsystem}/${type}")
          else if l.isAttrs subsystem
          then subsystem ? ${type}
          else throw "Translator can be a path or an attrset, but instead was ${l.typeOf subsystem}")
        translatorTypes;

      translatorsForTypes =
        l.genAttrs
        availableTypes
        (transType: function subsystemName subsystem transType);
    in
      translatorsForTypes
      // {
        all =
          l.foldl'
          (a: b: a // b)
          {}
          (l.attrValues translatorsForTypes);
      })
    subsystems;

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

  callTranslator = subsystem: type: name: mkModule: args: let
    translatorModule = mkModule {
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
    # subsystem can be a path or an attrset
    subsystemName: subsystem: type: let
      translatorNames =
        if l.isPath subsystem
        then dlib.dirNames "${subsystem}/${type}"
        else if l.isAttrs subsystem
        then l.attrNames (subsystem.${type} or {})
        # TODO: it would be sensible for translator leafs to be either functions or paths
        else throw "Translator can be a path or an attrset, but instead was ${l.typeOf subsystem}";

      translatorsLoaded =
        l.genAttrs
        translatorNames
        (translatorName:
          callTranslator
          subsystemName
          type
          translatorName
          (
            if l.isPath subsystem
            then (import "${subsystem}/${type}/${translatorName}")
            else if l.isAttrs subsystem
            then subsystem.${type}.${translatorName}
            # TODO: it would be sensible for translator leafs to be either functions or paths
            else throw "Translator can be a path or an attrset, but instead was ${l.typeOf subsystem}"
          )
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
