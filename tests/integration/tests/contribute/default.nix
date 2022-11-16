{
  lib,
  pkgs,
  self,
  framework,
  ...
}: let
  l = lib // builtins;
in
  framework.utils.writePureShellScript
  (with pkgs; [
    coreutils
    nix
  ])
  ''
    # create working dirs
    mkdir $TMPDIR/dream2nix

    # checkout dream2nix source code
    cd $TMPDIR/dream2nix
    cp -r ${self}/* .
    chmod -R +w .

    # fake git
    function git(){
      true
    }

    set -x
    source ${self}/docs/src/contributing/00-declare-variables.sh
    source ${self}/docs/src/contributing/01-initialize-templates.sh
    source ${self}/docs/src/contributing/02-initialize-example-flake.sh
    source ${self}/docs/src/contributing/03-add-files-to-git.sh
    source ${self}/docs/src/contributing/04-test-example-flake.sh
  ''
