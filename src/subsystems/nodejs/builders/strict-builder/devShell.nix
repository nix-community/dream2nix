{
  nodejs,
  pkg,
  pkgs,
}:
with pkgs;
  mkShell {
    buildInputs = [
      nodejs
    ];
    shellHook = let
      nodeModulesDir = pkg.deps;
    in ''
      # rsync the node_modules folder
      # - is way faster than copying everything again, because it only replaces updated files
      # - rsync can be restarted from any point, if failed or aborted mid execution.
      # Options:
      # -a -> all files recursive, preserve symlinks, etc.
      # -E -> preserve executables
      # --delete -> removes deleted files

      ID=${nodeModulesDir}

      mkdir -p .dream2nix
      if [[ "$ID" != "$(cat .dream2nix/.node_modules_id)" || ! -d "node_modules"  ]];
      then
        ${rsync}/bin/rsync -aE --chmod=ug+w  --delete ${nodeModulesDir}/ ./node_modules/
        # chmod -R +w ./node_modules

        echo $ID > .dream2nix/.node_modules_id
      fi

      export PATH="$PATH:$(realpath ./node_modules)/.bin"
    '';
  }
