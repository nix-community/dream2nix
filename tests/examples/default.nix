{
  self,
  lib,
  async,
  bash,
  coreutils,
  git,
  nix,
  utils,
  dream2nixWithExternals,
  ...
}: let
  l = lib // builtins;
  examples = ../../examples;
in
  utils.writePureShellScript
  [
    async
    bash
    coreutils
    git
    nix
  ]
  ''
    if [ -z ''${1+x} ]; then
      examples=$(ls ${examples})
    else
      examples=$1
    fi

    S=$(mktemp)
    async -s=$S server --start -j$(nproc)
    sleep 1

    for dir in $examples; do
      async -s=$S cmd -- bash -c "
        echo -e \"\ntesting example for $dir\"
        tmp=\$(mktemp -d)
        echo \"tempdir: \$tmp\"
        mkdir \$tmp
        cp -r ${examples}/$dir/* \$tmp/
        chmod -R +w \$tmp
        cd \$tmp
        nix flake lock --override-input dream2nix ${../../.}
        nix run .#resolveImpure
        nix flake check
        cd -
        rm -r \$tmp
      "
    done

    async -s=$S wait
    rm $S
  ''
