{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    ../../drv-parts/nodejs-package-lock
    ../../drv-parts/nodejs-granular
    ../../drv-parts/pip
  ];

  name = "isso";
  version = "0.13.0";

  deps = {nixpkgs, ...}: {
    stdenv = l.mkForce nixpkgs.stdenv;
    jq = l.mkForce nixpkgs.jq;
    fetchFromGitHub = nixpkgs.fetchFromGitHub;
  };

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "posativ";
      repo = config.name;
      rev = "refs/tags/${config.version}";
      sha256 = "sha256-kZNf7Rlb1DZtQe4dK1B283OkzQQcCX+pbvZzfL65gsA=";
    };
  };

  nodejs-granular = {
    installMethod = l.mkForce "copy";
    buildScript = l.mkForce "npm run build-prod";
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
