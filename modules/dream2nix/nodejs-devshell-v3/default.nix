{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;

  cfg = config.nodejs-devshell-v3;

  nodeModulesDir = "${cfg.nodeModules.public}/lib/node_modules/${config.name}/node_modules";
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.nodejs-package-lock-v3
  ];

  nodejs-devshell-v3.nodeModules = {
    imports = [
      {inherit (config) nodejs-package-lock-v3 name version;}
      {mkDerivation.src = l.mkForce null;}
    ];
  };

  nodejs-package-lock-v3.packageLockFile = "${config.mkDerivation.src}/package-lock.json";

  # rsync the node_modules folder
  # - tracks node-modules store path via .dream2nix/.node_modules_id
  # - omits copying if store path did not change
  # - if store path changes, only replaces updated files
  # - rsync can be restarted from any point, if failed or aborted mid execution.
  # Options:
  # -a            -> all files recursive, preserve symlinks, etc.
  # --delete      -> removes deleted files
  # --chmod=+ug+w -> make folder writeable by user+group
  mkDerivation.shellHook = ''
    ID=${nodeModulesDir}
    currID=$(cat .dream2nix/.node_modules_id 2> /dev/null)

    mkdir -p .dream2nix
    if [[ "$ID" != "$currID" || ! -d "node_modules"  ]];
    then
      ${config.deps.rsync}/bin/rsync -a --chmod=ug+w  --delete ${nodeModulesDir}/ ./node_modules/
      echo -n $ID > .dream2nix/.node_modules_id
      echo "Ok: node_modules updated"
    fi
  '';
}
