{
  config,
  dream2nix,
  lib,
  ...
}: let
  l = lib // builtins;

  buildPythonPackageOptions = import ../buildPythonPackage/options.nix {inherit config lib;};

  keepArg = key: val: buildPythonPackageOptions ? ${key};
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.mkDerivation-mixin
    dream2nix.modules.dream2nix.deps
  ];
  config = {
    package-func.func = config.deps.python.pkgs.buildPythonPackage;
    package-func.args = lib.filterAttrs keepArg config;

    deps = {nixpkgs, ...}: {
      python = l.mkOptionDefault nixpkgs.python3;
    };
  };
}
