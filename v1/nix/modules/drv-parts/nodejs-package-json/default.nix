{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.nodejs-package-json;

  npm =
    if l.versionOlder config.deps.npm.version "9"
    then config.deps.npm
    else throw "The version of config.deps.npm must be < 9";

  writers = import ../../../pkgs/writers {
    inherit lib;
    inherit
      (config.deps)
      bash
      coreutils
      gawk
      path
      writeScript
      writeScriptBin
      ;
  };

  npm_8 = nodejs:
    nodejs.pkgs.npm.override (old: rec {
      version = "8.19.4";
      src = builtins.fetchTarball {
        url = "https://registry.npmjs.org/npm/-/npm-${version}.tgz";
        sha256 = "0xmvjkxgfavlbm8cj3jx66mlmc20f9kqzigjqripgj71j6b2m9by";
      };
    });

  npmArgs = l.concatStringsSep " " (map (arg: "'${arg}'") cfg.npmArgs);
in {
  imports = [
    ./interface.nix
    ../nodejs-package-lock
    ../lock
  ];
  config = {
    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        inherit
          (nixpkgs)
          bash
          coreutils
          gawk
          path
          writeScript
          writeScriptBin
          ;
      };

    lock.fields.package-lock.script =
      writers.writePureShellScript
      [
        config.deps.coreutils
        npm
      ]
      ''
        source=${cfg.source}

        pushd $TMPDIR

        cp -r $source/* ./
        chmod -R +w ./
        rm -f package-lock.json
        npm install --package-lock-only ${npmArgs}

        mv package-lock.json $out

        popd
      '';

    nodejs-package-lock = {
      packageLockFile = null;
      packageLock = l.mkForce config.lock.content.package-lock;
    };
  };
}
