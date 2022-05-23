{
  config,
  dlib,
  lib,
}: let
  l = lib // builtins;

  # TODO
  validator = module: true;

  modules = dlib.modules.makeSubsystemModules {
    inherit validator;
    modulesCategory = "builders";
  };
in {
  callBuilder = modules.callModule;
  mapBuilders = modules.mapModules;
  builders = modules.modules;
}
