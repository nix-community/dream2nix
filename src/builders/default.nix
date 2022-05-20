{
  dlib,
  lib,
  callPackageDream,
  ...
}: let
  l = lib // builtins;

  defaults = {
    rust = "build-rust-package";
    python = "simple-builder";
    go = "gomod2nix";
    nodejs = "granular";
  };

  makeBuilder = builderModule:
    builderModule
    // {
      builder = callPackageDream builderModule.builder;
    };

  builders = dlib.builders.mapBuilders makeBuilder;
  buildersWithDefaults =
    l.mapAttrs
    (subsystem: attrs:
      attrs
      // {
        default = attrs.all."${defaults."${subsystem}"}";
      })
    builders;
in
  buildersWithDefaults
