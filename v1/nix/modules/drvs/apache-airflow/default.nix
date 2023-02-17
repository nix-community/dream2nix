{config, lib, drv-parts, ...}: let
  l = lib // builtins;
  python = config.deps.python;
  extractPythonAttrs = config.mach-nix.lib.extractPythonAttrs;

  nixpkgsAttrs = extractPythonAttrs python.pkgs.apache-airflow;

in {

  imports = [
    ../../drv-parts/mach-nix-xs
  ];

  deps = {nixpkgs, nixpkgsStable, ...}: {
    inherit (nixpkgs)
      git
      fetchFromGitHub
      ;
    python = l.mkForce nixpkgsStable.python3;
  };

  pname = "apache-airflow";
  version = "2.5.0";

  src = config.deps.fetchFromGitHub {
    owner = "apache";
    repo = "airflow";
    rev = "refs/tags/${config.version}";
    # Download using the git protocol rather than using tarballs, because the
    # GitHub archive tarballs don't appear to include tests
    forceFetchGit = true;
    hash = "sha256-QWUXSG+RSHkF5kP1ZYtx+tHjO0n7hfya9CFA3lBhJHk=";
  };

  mach-nix.pythonSources = config.deps.fetchPythonRequirements {
    inherit (config.deps) python;
    name = config.pname;
    requirementsList = [
      "apache-airflow"
    ];
    hash = "sha256-sj1UILnWbUyTcpgEEy8QtQEk+lTgBOJKa+NEUD3xVBs=";
    maxDate = "2023-01-01";
  };

  # Replace some python packages entirely with candidates from nixpkgs, because
  #   they are hard to fix
  mach-nix.substitutions = {
    cron-descriptor = python.pkgs.cron-descriptor;
    python-nvd3 = python.pkgs.python-nvd3;
    pendulum = python.pkgs.pendulum;
  };

  nativeBuildInputs = [
    python.pkgs.GitPython
  ];

  env = {
    inherit (nixpkgsAttrs)
      INSTALL_PROVIDERS_FROM_SOURCES
      disabledTests
      makeWrapperArgs
      pytestFlagsArray
      pythonImportsCheck
      ;
  };

  inherit (nixpkgsAttrs)
    buildInputs
    checkInputs
    postPatch
    postInstall
    preCheck
    ;

}
