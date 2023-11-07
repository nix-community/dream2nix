{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.nodejs-package-json;

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

  npmArgs = l.concatStringsSep " " (map (arg: "'${arg}'") cfg.npmArgs);
in {
  imports = [
    ./interface.nix
    ../nodejs-package-lock-v3
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
        npm = nixpkgs.nodejs.pkgs.npm;
      };

    lock.fields.package-lock.script =
      writers.writePureShellScript
      [
        config.deps.coreutils
        config.deps.npm
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

    lock.invalidationData = {
      packageJson = lib.importJSON (config.nodejs-package-json.source + /package.json);
    };

    nodejs-package-lock-v3 = {
      packageLockFile = null;
      packageLock = l.mkForce config.lock.content.package-lock;
    };
  };
}
