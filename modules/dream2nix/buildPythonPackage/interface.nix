{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  buildPythonPackageOptions = import ./options.nix {inherit config lib;};
in {
  options = {
    buildPythonPackage = buildPythonPackageOptions;
    deps.python = l.mkOption {
      type = t.package;
      description = "The python interpreter package to use";
    };
  };
  config = {
    buildPythonPackage.format = lib.mkOptionDefault (
      if config.buildPythonPackage.pyproject == null
      then "setuptools"
      else null
    );
  };
}
