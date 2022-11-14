{
  self,
  lib,
  async,
  bash,
  coreutils,
  git,
  parallel,
  nix,
  utils,
  dream2nixWithExternals,
  ...
}: let
  l = lib // builtins;
  tests = ./tests;
  testScript =
    utils.writePureShellScript
    [
      async
      bash
      coreutils
      git
      nix
    ]
    ''
      cd $TMPDIR
      dir=$1
      shift
      echo -e "\nrunning test $dir"
      start_time=$(date +%s)
      cp -r ${tests}/$dir/* .
      chmod -R +w .
      nix flake lock --override-input dream2nix ${../../.}
      nix run .#resolveImpure || echo "no resolveImpure probably?"
      nix build
      nix flake check
      end_time=$(date +%s)
      elapsed=$(( end_time - start_time ))
      echo -e "testing example for $dir took $elapsed seconds"
      echo "$elapsed sec: $dir" >> $STATS_FILE
    '';
in
  utils.writePureShellScript
  [
    coreutils
    parallel
  ]
  ''
    export STATS_FILE=$(mktemp)
    if [ -z ''${1+x} ]; then
      JOBS=''${JOBS:-$(nproc)}
      parallel --halt now,fail=1 -j$JOBS -a <(ls ${tests}) ${testScript}
    else
      arg1=$1
      shift
      ${testScript} $arg1 "$@"
    fi
    echo "done running flake integration tests"
    echo -e "\nExecution times:"
    cat $STATS_FILE | sort --numeric-sort
    rm $STATS_FILE
  ''
