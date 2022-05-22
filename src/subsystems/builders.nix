{
  dlib,
  callPackageDream,
  ...
}: let
  makeBuilder = builderModule:
    builderModule
    // {
      build = callPackageDream builderModule.build {};
    };

  builders = dlib.builders.mapBuilders makeBuilder;
in {
  inherit
    makeBuilder
    builders
    ;
}
