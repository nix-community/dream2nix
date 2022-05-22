{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # TODO
  validator = module: {
    success = true;
  };

  modules = dlib.makeSubsystemModules {
    inherit validator;
    modulesCategory = "builders";
  };
in {
  callBuilder = modules.callModule;
  mapBuilders = modules.mapModules;
  builders = modules.modules;
}
