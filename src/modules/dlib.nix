{lib}: let
  libModule = {
    options = {
      lib = lib.mkOption {
        type = lib.types.raw;
      };
    };
    config = {
      inherit lib;
    };
  };
in
  (lib.evalModules {modules = [libModule ./dlib];}).config.dlib
