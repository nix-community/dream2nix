{
  lib,
  # This python is for the locking logic, not the python to lock packages for.
  python3,
  gitMinimal,
  nix-prefetch-scripts,
}: let
  package = python3.pkgs.buildPythonPackage {
    name = "fetch-pip-metadata";
    format = "pyproject";
    src = ./src;
    nativeBuildInputs = [
      gitMinimal
      python3.pkgs.pytestCheckHook
    ];
    propagatedBuildInputs = with python3.pkgs; [
      packaging
      certifi
      flit-core
      nix-prefetch-scripts
      python-dateutil
      pip
    ];

    meta.mainProgram = "fetch_pip_metadata";
  };
in
  package
