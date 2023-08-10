{
  lib,
  python,
  git,
  nix-prefetch-scripts,
}: let
  package = python.pkgs.buildPythonPackage {
    name = "fetch_pip_metadata";
    format = "flit";
    src = ./src;
    nativeBuildInputs = [
      git
      python.pkgs.pytestCheckHook
      nix-prefetch-scripts
    ];
    propagatedBuildInputs = with python.pkgs; [
      packaging
      certifi
      python-dateutil
      pip
    ];
  };
in
  package
