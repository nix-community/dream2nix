{
  lib,
  # Specify the python version for which the packages should be downloaded.
  # Pip needs to be executed from that specific python version.
  # Pip accepts '--python-version', but this works only for wheel packages.
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
