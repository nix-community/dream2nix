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
in {
  imports = [
    ../../drv-parts/nodejs-package-lock
    ../../drv-parts/nodejs-granular
  ];

  name = "${name}-frontend";
  inherit version;

  deps = {nixpkgs, ...}: {
    jq = l.mkForce nixpkgs.jq;
    npm = nixpkgs.nodePackages.npm;
    inherit (nixpkgs) fetchFromGitHub;
  };

  mkDerivation.buildInputs = [
    config.deps.jq
    config.deps.npm
  ];

  mkDerivation = {
    inherit src;
  };

  nodejs-granular = {
    installMethod = "symlink";
    buildScript = "npm run build-prod";
    runBuild = true;
  };
}
