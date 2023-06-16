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
    ../../drv-parts/pip
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
    python = nixpkgs.python3;
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

  pip = {
    pypiSnapshotDate = "2023-01-01";
    requirementsList = [
      "apache-airflow"
      "setuptools-scm"
    ];

    drvs = {
      # We include fixes from nixpkgs for pendulum, but keep
      # our dependencies to avoid version conflicts
      pendulum.nixpkgs-overrides = {
        enable = true;
        exclude = ["propagatedBuildInputs"];
      };
      lazy-object-proxy.mkDerivation = {
        # setuptools-scm is required by lazy-object-proxy,
        # we include it in our requirements above instead of
        # using the version from nixpkgs to ensure that
        # transistive dependencies (i.e. typing-extensions) are
        # compatible with the rest of our lock file.

        buildInputs = [config.pip.drvs.setuptools-scm.public];
      };
    };
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
