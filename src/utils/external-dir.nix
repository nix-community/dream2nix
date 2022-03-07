{
  lib ? pkgs.lib,
  pkgs,
  externalSources,
  externalPaths,
}:
pkgs.runCommand "dream2nix-external-dir" {}
(lib.concatStringsSep "\n"
  (lib.mapAttrsToList
    (inputName: paths:
      lib.concatStringsSep "\n"
      (lib.forEach
        paths
        (path: ''
          mkdir -p $out/${inputName}/$(dirname ${path})
          cp ${externalSources."${inputName}"}/${path} $out/${inputName}/${path}
        '')))
    externalPaths))
