{
  lib,
  python,
  git,
}: let
  package = python.pkgs.buildPythonPackage {
    name = "fetch_pip_metadata";
    format = "flit";
    src = ./src;
    nativeBuildInputs = [
      git
      python.pkgs.pytestCheckHook
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
