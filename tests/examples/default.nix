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
      dir=$1
      echo -e \"\ntesting example for $dir\"
      cp -r ${examples}/$dir/* .
      chmod -R +w .
      nix flake lock --override-input dream2nix ${../../.}
      nix run .#resolveImpure
      nix flake check
    '';
in
  utils.writePureShellScript
  [
    coreutils
    parallel
  ]
  ''
    if [ -z ''${1+x} ]; then
      parallel --halt now,fail=1 -j$(nproc) -a <(ls ${examples}) ${testScript}
    else
      ${testScript} $1
    fi
  ''
