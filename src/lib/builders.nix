{
  config,
  dlib,
  lib,
}: let
  l = lib // builtins;

  # TODO
  validator = module: true;

  modules = dlib.makeSubsystemModules {
    inherit validator;
    modulesCategory = "builders";
    extraModules = config.extraBuilders or [];
  };
in {
  callBuilder = modules.callModule;
  mapBuilders = modules.mapModules;
  builders = modules.modules;
}
