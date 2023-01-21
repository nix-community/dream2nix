{
  nodejs,
  nodeModules,
  pkgs,
}:
pkgs.mkShell {
  buildInputs = [
    nodejs
  ];

  shellHook = ''
    # rsync the node_modules folder
    # - way faster than copying everything again, because it only replaces updated files
    # - rsync can be restarted from any point, if failed or aborted mid execution.
    # Options:
    # -a            -> all files recursive, preserve symlinks, etc.
    # --delete      -> removes deleted files
    # --chmod=+ug+w -> make folder writeable by user+group

    ID=${nodeModules}
    currID=$("$(cat .dream2nix/.node_modules_id)" 2> /dev/null)

    mkdir -p .dream2nix
    if [[ "$ID" != "$currID" || ! -d "node_modules"  ]];
    then
      ${pkgs.rsync}/bin/rsync -a --chmod=ug+w  --delete ${nodeModules}/ ./node_modules/
      echo $ID > .dream2nix/.node_modules_id
      echo "Ok: node_modules updated"
    fi

    export PATH="$PATH:$(realpath ./node_modules)/.bin"
  '';
}
