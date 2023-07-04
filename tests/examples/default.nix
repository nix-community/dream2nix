{
  self,
  lib,
  async,
  bash,
  coreutils,
  git,
  gnugrep,
  gnused,
  jq,
  parallel,
  moreutils,
  nix,
  pkgs,
  framework,
  ...
}: let
  l = lib // builtins;
  examples = ../../examples;
  testScript =
    framework.utils.writePureShellScript
    [
      async
      bash
      coreutils
      git
      gnugrep
      gnused
      jq
      moreutils
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
      if [ -n "''${NIX:-}" ]; then
        PATH="$(dirname $NIX):$PATH"
      fi

      # Override `systems` in the flake.nix to only contain the current one.
      # We don't want to expose multiple systems to reduce evaluation overhead.
      sed "s/x86_64-linux/$NIX_SYSTEM/g" flake.nix | sponge flake.nix

      nix flake lock --override-input dream2nix ${../../.}
      if nix flake show | grep -q resolveImpure; then
        nix run .#resolveImpure --show-trace
      fi
      # disable --read-only check for these because they do IFD so they will
      # write to store at eval time
      evalBlockList=("haskell_cabal-plan" "haskell_stack-lock")
      if [[ ! ((''${evalBlockList[*]} =~ "$dir")) ]] \
          && [ "$(nix flake show --json | jq 'select(.packages."$NIX_SYSTEM".default.name)')" != "" ]; then
        nix eval --read-only --no-allow-import-from-derivation .#default.name
      fi
      nix flake check "$@"
      end_time=$(date +%s)
      elapsed=$(( end_time - start_time ))
      echo -e "testing example for $dir took $elapsed seconds"
      echo "$elapsed sec: $dir" >> $STATS_FILE
    '';
in
  framework.utils.writePureShellScript
  [
    coreutils
    nix
    parallel
  ]
  ''
    export STATS_FILE=$(mktemp)
    export NIX_SYSTEM=$(nix eval --impure --expr builtins.currentSystem --raw)
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
