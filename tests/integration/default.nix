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
      dir=$1
      shift
      echo -e "\nrunning test $dir"
      cp -r ${tests}/$dir/* .
      chmod -R +w .
      nix flake lock --override-input dream2nix ${../../.}
      nix run .#resolveImpure || echo "no resolveImpure probably?"
      nix eval --read-only --no-allow-import-from-derivation .#default.name
      nix build
      nix flake check "$@"
    '';
in
  utils.writePureShellScript
  [
    coreutils
    parallel
  ]
  ''
    if [ -z ''${1+x} ]; then
      parallel --halt now,fail=1 -j$(nproc) -a <(ls ${tests}) ${testScript}
    else
      arg1=$1
      shift
      ${testScript} $arg1 "$@"
    fi
    echo "done running integration tests"
  ''
