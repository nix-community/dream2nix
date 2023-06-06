{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  name = "isso";
  version = "0.13.0";
  src = config.deps.fetchFromGitHub {
    owner = "posativ";
    repo = name;
    rev = "refs/tags/${version}";
    sha256 = "sha256-kZNf7Rlb1DZtQe4dK1B283OkzQQcCX+pbvZzfL65gsA=";
  };
  frontend = {config, ...}: {
    imports = [
      ../../drv-parts/nodejs-package-lock
      ../../drv-parts/nodejs-granular
    ];

    name = "${name}-frontend";
    inherit version;

    deps = {nixpkgs, ...}: {
      jq = l.mkForce nixpkgs.jq;
      npm = nixpkgs.nodePackages.npm;
    };

    mkDerivation = {
      inherit src;
      buildInputs = [
        config.deps.jq
        config.deps.npm
      ];
    };
    nodejs-granular = {
      installMethod = l.mkForce "copy";
      buildScript = l.mkForce "npm run build-prod";
      runBuild = true;
    };
  };
in {
  imports = [
    ../../drv-parts/pip
  ];

  inherit name version;

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python3;
    fetchFromGitHub = nixpkgs.fetchFromGitHub;
  };

  mkDerivation = {
    inherit src;
    # Isso implicitly depends on setuptools via pkg_resources
    propagatedBuildInputs = [
      config.deps.python.pkgs.setuptools
      config.pip.drvs.frontend.public
    ];
  };

  buildPythonPackage = {
    pythonImportsCheck = [
      config.name
    ];
  };

  pip = {
    # FIXME this will be changed to depsModules or so
    drvs = {inherit frontend;};
    pypiSnapshotDate = "2023-05-30";
    requirementsList = ["${config.name}==${config.version}"];
  };
}
