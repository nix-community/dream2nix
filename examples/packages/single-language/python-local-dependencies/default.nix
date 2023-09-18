{
  config,
  lib,
  dream2nix,
  ...
}: let
  pyproject = lib.importTOML ./subpkg1/pyproject.toml;
  buildWithSetuptools = {
    buildPythonPackage.format = "pyproject";
    mkDerivation.buildInputs = [config.deps.python.pkgs.setuptools];
  };
in rec {
  imports = [
    dream2nix.modules.dream2nix.pip
    buildWithSetuptools
  ];

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
    drvs.subpkg2 = buildWithSetuptools;
  };
}
