{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  python = config.deps.python;
  extractPythonAttrs = config.nixpkgs-overrides.lib.extractPythonAttrs;
  nixpkgsAttrs = extractPythonAttrs python.pkgs.apache-airflow;
in {
  imports = [
    ../../drv-parts/mach-nix-xs
    ../../drv-parts/nixpkgs-overrides
  ];

  deps = {
    nixpkgs,
    nixpkgsStable,
    ...
  }: {
    inherit
      (nixpkgs)
      git
      fetchFromGitHub
      ;
  };

  name = "apache-airflow";
  version = "2.5.0";

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "apache";
      repo = "airflow";
      rev = "refs/tags/${config.version}";
      # Download using the git protocol rather than using tarballs, because the
      # GitHub archive tarballs don't appear to include tests
      forceFetchGit = true;
      hash = "sha256-QWUXSG+RSHkF5kP1ZYtx+tHjO0n7hfya9CFA3lBhJHk=";
    };

    nativeBuildInputs = [
      python.pkgs.GitPython
    ];

    inherit
      (nixpkgsAttrs)
      buildInputs
      checkInputs
      postPatch
      postInstall
      preCheck
      ;
  };

  mach-nix.pythonSources.fetch-pip = {
    pypiSnapshotDate = "2023-01-01";
    requirementsList = [
      "apache-airflow"
    ];
  };

  # Replace some python packages entirely with candidates from nixpkgs, because
  #   they are hard to fix
  mach-nix.substitutions = {
    cron-descriptor = python.pkgs.cron-descriptor;
    python-nvd3 = python.pkgs.python-nvd3;
    pendulum = python.pkgs.pendulum;
  };

  env = {
    inherit
      (nixpkgsAttrs)
      INSTALL_PROVIDERS_FROM_SOURCES
      makeWrapperArgs
      ;
  };

  buildPythonPackage = {
    inherit
      (nixpkgsAttrs)
      disabledTests
      pythonImportsCheck
      pytestFlagsArray
      ;
  };
}
