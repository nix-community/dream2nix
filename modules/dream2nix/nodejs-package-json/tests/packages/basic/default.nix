{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-package-json
    dream2nix.modules.dream2nix.nodejs-granular
  ];

  nodejs-package-lock = {
    source = ./.;
  };

  paths.projectRootFile = "package.json";

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
    npm = nixpkgs.nodejs.pkgs.npm.override rec {
      version = "8.19.4";
      src = nixpkgs.fetchurl {
        url = "https://registry.npmjs.org/npm/-/npm-${version}.tgz";
        hash = "sha256-JmehuDAPMV0iPkPDB/vpRuuLl3kq85lCTvZ+qcsKcvY=";
      };
    };
  };

  name = lib.mkForce "app";
  version = lib.mkForce "1.0.0";

  nodejs-granular = {
    buildScript = ''
      tsc ./app.ts
      mv app.js app.js.tmp
      echo "#!${config.deps.nodejs}/bin/node" > app.js
      cat app.js.tmp >> app.js
      chmod +x ./app.js
      patchShebangs .
    '';
  };

  mkDerivation = {
    src = ./.;
    checkPhase = ''
      [[ "Hello, World!" =~ "$(./app.js)" ]]
    '';
    doCheck = true;
  };
}
