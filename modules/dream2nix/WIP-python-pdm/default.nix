{
  config,
  lib,
  dream2nix,
  ...
}: let
  libpdm = ./lib.nix {
    inherit lib libpyproject;
  };

  libpyproject = import (dream2nix.inputs.pyproject-nix + "/lib") {inherit lib;};

  lock-data = libpdm.parseLockData {
    lock-data = lib.importTOML config.pdm.lock-file;
    environ = libpyproject.pep508.mkEnviron config.deps.python3;
    selector = libpdm.preferWheelSelector;
  };

  pyproject-data = lib.importTOML config.pdm.pyproject;

  pyprojectLoaded = libpyproject.project.loadPyproject {
    pyproject = pyproject-data;
  };

  build-systems = pyprojectLoaded.build-systems;
  dependencies = pyprojectLoaded.dependencies;
in {
  imports = [
    dream2nix.modules.dream2nix.groups
    ./interface.nix
  ];
  commonModule = {
    options.sourceSelector = import ./sourceSelectorOption.nix {};
    config.sourceSelector = lib.mkOptionDefault config.pdm.sourceSelector;
  };
}
