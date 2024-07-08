{
  config,
  lib,
  dream2nix,
  ...
}: let
  python = config.deps.python;
in {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {
    nixpkgs,
    nixpkgsStable,
    ...
  }: {
    inherit
      (nixpkgs)
      apache-airflow
      git
      fetchFromGitHub
      ;
    python = nixpkgs.python310;
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
  };

  pip = {
    requirementsList = [
      "apache-airflow"
      "setuptools-scm"
    ];

    overrides = {
      # We include fixes from nixpkgs for pendulum, but keep
      # our dependencies to avoid version conflicts
      pendulum = {
        buildPythonPackage.pyproject = true;
        mkDerivation.propagatedBuildInputs = [
          python.pkgs.poetry-core
        ];
      };
      lazy-object-proxy = {
        # setuptools-scm is required by lazy-object-proxy,
        # we include it in our requirements above instead of
        # using the version from nixpkgs to ensure that
        # transitive dependencies (i.e. typing-extensions) are
        # compatible with the rest of our lock file.
        mkDerivation.buildInputs = [config.pip.drvs.setuptools-scm.public];
      };
    };
  };
}
