{
  lib,
  python3,
  nix-prefetch-scripts,
}: let
  pythonWithPkgs = python3;
in
  pythonWithPkgs.pkgs.buildPythonApplication {
    pname = "fetch-composer-metadata";
    version = "0.1.0";
    pyproject = true;

    src = ./src;

    build-system = [pythonWithPkgs.pkgs.setuptools];

    propagatedBuildInputs = [
      nix-prefetch-scripts
    ];

    meta.mainProgram = "fetch_composer_metadata";
  }
