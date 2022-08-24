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
  examples = ../../examples;
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
      echo -e "\ntesting example for $dir"
      start_time=$(date +%s)
      cp -r ${examples}/$dir/* .
      chmod -R +w .
      nix flake lock --override-input dream2nix ${../../.}
      nix run .#resolveImpure --show-trace
      # disable --read-only check for these because they do IFD so they will
      # write to store at eval time
      evalBlockList=("haskell_cabal-plan" "haskell_stack-lock")
      if [[ ! ((''${evalBlockList[*]} =~ "$dir")) ]]; then
        nix eval --read-only --no-allow-import-from-derivation .#default.name
      fi
      nix flake check "$@"
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
      parallel --halt now,fail=1 -j$JOBS -a <(ls ${examples}) ${testScript}
    else
      arg1=$1
      shift
      ${testScript} $arg1 "$@"
    fi
    echo -e "\nExecution times:"
    cat $STATS_FILE | sort --numeric-sort
    rm $STATS_FILE
  ''
