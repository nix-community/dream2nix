{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  buildPythonPackageOptions = import ../buildPythonPackage/options.nix {inherit config lib;};
in {
  options =
    buildPythonPackageOptions
    // {
      deps.python = l.mkOption {
        type = t.package;
        description = "The python interpreter package to use";
      };
    };

  config = {
    format = lib.mkOptionDefault (
      if config.pyproject == null
      then "setuptools"
      else null
    );
  };
}
