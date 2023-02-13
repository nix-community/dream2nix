{config, lib, drv-parts, ...}: let
  l = lib // builtins;
  python = config.deps.python;

in {

  imports = [
    ../drv-parts/mach-nix-xs
  ];

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) fetchFromGitHub;
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

  pythonSources = config.deps.fetchPythonRequirements {
    inherit (config.deps) python;
    requirementsList = [
      "apache-airflow"
    ];
    hash = "sha256-ZEeIVAsHoKq9g25+b7XWUSOf2/HUYMUAPl30IRG+Zak=";
    maxDate = "2023-01-01";
  };

  # Replace some python packages entirely with candidates from nixpkgs, because
  #   they are hard to fix
  substitutions = {
    cron-descriptor = python.pkgs.cron-descriptor;
    python-nvd3 = python.pkgs.python-nvd3;
  };
}
