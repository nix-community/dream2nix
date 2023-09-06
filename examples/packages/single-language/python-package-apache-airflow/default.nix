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
      pendulum = {
        imports = [
          dream2nix.modules.dream2nix.nixpkgs-overrides
        ];
        nixpkgs-overrides = {
          exclude = ["propagatedBuildInputs"];
        };
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
}
