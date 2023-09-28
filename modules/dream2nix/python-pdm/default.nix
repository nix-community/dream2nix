{
  config,
  lib,
  dream2nix,
  ...
}: let
  t = lib.types;
  pyproject-nix = import (dream2nix.inputs.pyproject-nix + "/lib") {inherit lib;};
  interpreterVersion = config.pythonInterpreter.pythonVersion;

  lock-data = lib.importTOML config.pdm.lock-file;
  pyproject-data = lib.importTOML config.pdm.pyproject;

  pyproject-parsed = pyproject-nix.project.loadPyproject {
    pyproject = pyproject-data;
  };
in {
  imports = [
    dream2nix.modules.groups
    ./interface.nix
  ];
  pdm.debugData = pyproject-parsed;
  commonModule = {
    options.sourceSelector = import ./sourceSeelctorOption.nix {};
    config.sourceSelector = lib.mkOptionDefault config.pdm.sourceSelector;
  };
}
