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
    mkdir $TMPDIR/{dream2nix,test-flake}

    # checkout dream2nix source code
    cd $TMPDIR/dream2nix
    cp -r ${self}/* .
    chmod -R +w .

    # define names for new modules
    subsystem="my-subsystem"
    pureTranslator="my-pure-translator"
    impureTranslator="my-impure-translator"
    builder="my-builder"

    # initialize pure translator
    mkdir -p ./src/subsystems/$subsystem/translators/$pureTranslator
    cp ./src/templates/translators/pure.nix ./src/subsystems/$subsystem/translators/$pureTranslator/default.nix

    # initialize builder
    mkdir -p ./src/subsystems/$subsystem/builders/$builder
    cp ./src/templates/builders/default.nix ./src/subsystems/$subsystem/builders/$builder/default.nix

    # initialize flake for building a test package
    cp ${./my-flake.nix} $TMPDIR/test-flake/flake.nix
    cd $TMPDIR/test-flake
    nix flake lock --override-input dream2nix $TMPDIR/dream2nix --show-trace

    # test `nix flake show`
    nix flake show --show-trace

    # build test package
    nix build .#default --show-trace
  ''
