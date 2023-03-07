{config, lib, ...}: let
  l = lib // builtins;

in {
  config = {
    package-func.func = config.deps.python.pkgs.buildPythonPackage;
    package-func.args = config.buildPythonPackage;

    deps = {nixpkgs, ...}: {
      python = l.mkOptionDefault nixpkgs.python3;
    };
  };
}
