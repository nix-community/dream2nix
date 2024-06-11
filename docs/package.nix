{
  lib,
  python3,
}: let
  package = python3.pkgs.buildPythonPackage {
    name = "dream2nix_docs";
    format = "pyproject";
    src = ./.;
    nativeBuildInputs = [
      python3.pkgs.setuptools
    ];
    propagatedBuildInputs = with python3.pkgs; [
      mkdocs
    ];
  };
in
  package
