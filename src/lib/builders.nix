{
  dlib,
  lib,
  config,
}: let
  l = lib // builtins;

  defaults = {
    rust = "build-rust-package";
    nodejs = "granular";
    python = "simple-builder";
  };

  # TODO
  validator = module: true;

  modules = dlib.modules.makeSubsystemModules {
    inherit validator defaults;
    modulesCategory = "builders";
  };

  builders =
    dlib.modules.mapSubsystemModules
    (b: b // {build = dlib.warnIfIfd b b.build;})
    modules.modules;
  mapBuilders = f: dlib.modules.mapSubsystemModules f builders;
in {
  inherit builders mapBuilders;
  callBuilder = modules.callModule;
}
