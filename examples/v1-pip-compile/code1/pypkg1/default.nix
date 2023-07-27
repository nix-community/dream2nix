# NOTE: Move into top-level subdirectory to have all nix tooling in one place?
{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.drv-parts.pip
  ];

  name = "pypkg1";
  version = "1";

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      stdenv
      ;
    python = nixpkgs.python310;
    setuptools = nixpkgs.python310Packages.setuptools;
  };

  mkDerivation = {
    src = ./.;

    # NOTE: Should be taken from pyproject.toml [build-sytem].
    nativeBuildInputs = [
      config.deps.setuptools
    ];
  };

  buildPythonPackage = {
    format = "pyproject";
  };

  pip = {
    # NOTE: Pass via CLI or define once for multiple packages?
    pypiSnapshotDate = "2023-06-30";

    requirementsFiles = [
      # NOTE: Switch flavour in central location
      # "code1/pypkg1/requirements.txt",
      "code1/pypkg1/requirements-dev.txt"
    ];
  };
}
