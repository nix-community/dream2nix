{
  self,
  lib,
  async,
  bash,
  coreutils,
  git,
  parallel,
  nix,
  pkgs,
  utils,
  dream2nixWithExternals,
  callPackageDream,
  ...
}: let
  l = lib // builtins;
  testDirs = l.attrNames (l.readDir ./tests);
  testScripts =
    map
    (dir: callPackageDream (./tests + "/${dir}") {inherit self;})
    testDirs;
  testScriptsFile = pkgs.writeText "scripts-list" (l.concatStringsSep "\n" testScripts);
  execTest =
    utils.writePureShellScript
    [
      bash
      coreutils
    ]
    ''
      cd $TMPDIR
      test=$1
      shift
      echo -e "\nrunning test $test"
      start_time=$(date +%s)

      bash "$test"

      end_time=$(date +%s)
      elapsed=$(( end_time - start_time ))
      echo -e "testing example for $test took $elapsed seconds"
      echo "$elapsed sec: $test" >> $STATS_FILE
    '';
in
  utils.writePureShellScript
  [
    bash
    coreutils
    parallel
  ]
  ''
    export STATS_FILE=$(mktemp)
    JOBS=''${JOBS:-$(nproc)}
    parallel --halt now,fail=1 -j$JOBS -a ${testScriptsFile} ${execTest}
    echo "done running integration tests"
    echo -e "\nExecution times:"
    cat $STATS_FILE | sort --numeric-sort
    rm $STATS_FILE
  ''
