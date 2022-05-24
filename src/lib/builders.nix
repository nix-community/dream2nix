{
  config,
  dlib,
  lib,
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
in {
  callBuilder = modules.callModule;
  mapBuilders = modules.mapModules;
  builders = modules.modules;
}
