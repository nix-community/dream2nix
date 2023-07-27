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

  npmArgs = l.concatStringsSep " " (map (arg: "'${arg}'") cfg.npmArgs);
in {
  imports = [
    ./interface.nix
    ../nodejs-package-lock
    ../lock
    ../writers
  ];
  config = {
    lock.fields.package-lock.script =
      config.writers.writePureShellScript
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
