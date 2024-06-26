{
  config,
  lib,
  dream2nix,
  ...
}: let
  pyproject = lib.importTOML ./subpkg1/pyproject.toml;
  buildWithSetuptools = {
    buildPythonPackage.pyproject = true;
    mkDerivation.buildInputs = [config.deps.python.pkgs.setuptools];
  };
in {
  imports = [
    dream2nix.modules.dream2nix.pip
    buildWithSetuptools
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python310;
  };

  inherit (pyproject.project) name version;

  mkDerivation.src = lib.concatStringsSep "/" [
    config.paths.projectRoot
    config.paths.package
    "subpkg1"
  ];

  buildPythonPackage.pythonImportsCheck = [
    "subpkg1"
    "subpkg2"
  ];

  pip = {
    pypiSnapshotDate = "2023-09-19";
    requirementsList = [
      "${config.paths.package}/subpkg1"
      "${config.paths.package}/subpkg2"
    ];
    overrides.subpkg2 = buildWithSetuptools;
  };
}
