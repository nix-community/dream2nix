# This example builds https://isso-comments.de. It's meant as a relatively
# simple demonstration on how to build applications consiting of a python
# backend and a javascript frontend, built with nodejs.
#
# To actually run an isso server with this, you'd also need a configuration file,
# see https://posativ.org/isso/docs/configuration/server/
{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.dream2nix.nodejs-package-lock
    dream2nix.modules.dream2nix.nodejs-granular
    dream2nix.modules.dream2nix.pip
  ];

  name = "isso";
  version = "0.13.0";

  deps = {nixpkgs, ...}: {
    jq = lib.mkForce nixpkgs.jq;
    fetchFromGitHub = nixpkgs.fetchFromGitHub;
    python = nixpkgs.python310;
  };

  nodejs-package-lock = {
    source = config.deps.fetchFromGitHub {
      owner = "posativ";
      repo = config.name;
      rev = "refs/tags/${config.version}";
      sha256 = "sha256-kZNf7Rlb1DZtQe4dK1B283OkzQQcCX+pbvZzfL65gsA=";
    };
  };

  mkDerivation = {
    src = config.nodejs-package-lock.source;

    propagatedBuildInputs = [
      # isso implicitly assumes that pkg_resources, which is
      # part of setuptools.
      config.deps.python.pkgs.setuptools
    ];
  };

  nodejs-granular = {
    installMethod = lib.mkForce "copy";
    buildScript = lib.mkForce "npm run build-prod";
    # runBuild = true;
    # TODO: create a better interface for overrides
    deps.delayed-stream."1.0.0" = {
      mkDerivation.preBuildPhases = ["removeMakefilePhase"];
      env.removeMakefilePhase = "rm Makefile";
    };
  };

  buildPythonPackage = {
    pythonImportsCheck = [
      config.name
    ];
  };

  pip = {
    pypiSnapshotDate = "2023-05-30";
    requirementsList = [
      "${config.name}==${config.version}"
      "setuptools"
    ];
  };
}
