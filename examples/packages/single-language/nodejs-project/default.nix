{
  lib,
  config,
  dream2nix,
  ...
}: let
  system = config.deps.stdenv.system;
in {
  imports = [
    dream2nix.modules.dream2nix.nodejs-package-json
    dream2nix.modules.dream2nix.nodejs-granular-v3
  ];

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      gnugrep
      stdenv
      ;
  };

  nodejs-granular-v3 = {
    buildScript = ''
      tsc ./app.ts
      mv app.js app.js.tmp
      echo "#!${config.deps.nodejs}/bin/node" > app.js
      cat app.js.tmp >> app.js
      chmod +x ./app.js
      patchShebangs .
    '';
  };

  name = lib.mkForce "app";
  version = lib.mkForce "1.0.0";

  lock.lockFileRel =
    lib.mkForce "/locks/example-package-nodejs-no-lock/lock-${system}.json";

  mkDerivation = {
    src = lib.cleanSource ./.;
    checkPhase = ''
      ./app.js | ${config.deps.gnugrep}/bin/grep -q "Hello, World!"
    '';
    doCheck = true;
  };
}
