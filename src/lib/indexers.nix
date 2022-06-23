{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # TODO
  validator = module: true;

  modules = dlib.modules.makeSubsystemModules {
    inherit validator;
    modulesCategory = "indexers";
  };

  indexers = modules.modules;
  mapIndexers = f: dlib.modules.mapSubsystemModules f indexers;
in {
  inherit indexers mapIndexers;
  callIndexer = modules.callModule;
}
