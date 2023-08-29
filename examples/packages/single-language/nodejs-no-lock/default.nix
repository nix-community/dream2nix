{
  lib,
  config,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  system = config.deps.stdenv.system;
in {
  imports = [
    dream2nix.modules.drv-parts.nodejs-package-json
    dream2nix.modules.drv-parts.nodejs-granular
  ];

  mkDerivation = {
    src = lib.cleanSource ./.;
    checkPhase = ''
      ./app.js | ${config.deps.gnugrep}/bin/grep -q "Hello, World!"
    '';
    doCheck = true;
  };

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

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      gnugrep
      stdenv
      ;
  };

  name = l.mkForce "app";
  version = l.mkForce "0.0.0";

  lock.lockFileRel =
    l.mkForce "/locks/example-package-nodejs-no-lock/lock-${system}.json";
}
