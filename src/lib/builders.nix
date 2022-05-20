{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # INTERNAL

  subsystems = dlib.dirNames ../builders;

  builderTypes = ["ifd" "pure"];

  # attrset of: subsystem -> builder-type -> (function subsystem builder-type)
  mkBuildersSet = function:
    l.genAttrs
    (dlib.dirNames ../builders)
    (subsystem: let
      availableTypes =
        l.filter
        (type: l.pathExists (../builders + "/${subsystem}/${type}"))
        builderTypes;

      buildersForTypes =
        l.genAttrs
        availableTypes
        (type: function subsystem type);
    in
      buildersForTypes
      // {
        all =
          l.foldl'
          (a: b: a // b)
          {}
          (l.attrValues buildersForTypes);
      });

  callBuilder = subsystem: type: name: file: let
    builderModule = {
      build = import file;
      inherit name subsystem type;
    };
  in
    builderModule;

  # EXPORTED

  # attrset of: subsystem -> builder-type -> builder
  builders = mkBuildersSet (
    subsystem: type: let
      builderNames =
        dlib.dirNames (../builders + "/${subsystem}/${type}");

      buildersLoaded =
        l.genAttrs
        builderNames
        (
          builderName:
            callBuilder
            subsystem
            type
            builderName
            (../builders + "/${subsystem}/${type}/${builderName}")
        );
    in
      l.filterAttrs
      (name: t: t.disabled or false == false)
      buildersLoaded
  );

  mapBuilders = f:
    l.mapAttrs
    (subsystem: types:
      l.mapAttrs
      (type: names:
        l.mapAttrs
        (name: builder: f builder)
        names)
      types)
    builders;
in {
  inherit
    mapBuilders
    builders
    ;
}
