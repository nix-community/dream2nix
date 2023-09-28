{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.pdm = {
    lockfile = l.mkOption {
      type = t.path;
    };
    pyproject = l.mkOption {
      type = t.path;
    };
    pythonInterpreter = l.mkOption {
      type = t.package;
    };

    debugData = l.mkOption {
      type = t.raw;
    };

    sourceSelector = import ./sourceSelectorOption.nix {inherit lib;};
  };
}
