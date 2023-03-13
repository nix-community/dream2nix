{
  config,
  lib,
  drv-parts,
  ...
}: let
  l = lib // builtins;
  python = config.deps.python;
  extractPythonAttrs = config.attrs-from-nixpkgs.lib.extractPythonAttrs;

  nixpkgsAttrs = extractPythonAttrs python.pkgs.apache-airflow;
in {
  imports = [
    ../../drv-parts/mach-nix-xs
    ../../drv-parts/attrs-from-nixpkgs
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

  public = {
    name = "apache-airflow";
    version = "2.5.0";
  };

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "apache";
      repo = "airflow";
      rev = "refs/tags/${config.public.version}";
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

  mach-nix.pythonSources = config.deps.fetchPythonRequirements {
    inherit (config.deps) python;
    name = config.public.name;
    requirementsList = [
      "apache-airflow"
    ];
    hash = "sha256-o5Gu069nB54/cI1muPfzrMX4m/Nm+pPOu1nUarNqeHM=";
    maxDate = "2023-01-01";
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
