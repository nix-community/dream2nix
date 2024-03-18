{
  config,
  dream2nix,
  lib,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.deps
  ];
  config = {
    package-func.func = config.deps.python.pkgs.buildPythonPackage;
    package-func.args = config.buildPythonPackage;

    deps = {nixpkgs, ...}: {
      python = l.mkOptionDefault nixpkgs.python3;
    };
  };
}
