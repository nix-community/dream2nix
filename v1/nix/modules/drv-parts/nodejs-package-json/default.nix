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
        inherit (nixpkgs.nodePackages) npm;
      };

    lock.fields.package-lock.script =
      writers.writePureShellScript
      (with config.deps; [
        coreutils
        npm
      ])
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
