{
  self,
  lib,
  coreutils,
  nix,
  git,
  python3,
  framework,
  ...
}: let
  l = lib // builtins;

  pythonEnv = python3.withPackages (ps:
    with ps; [
      pytest
      pytest-xdist
    ]);
in
  framework.utils.writePureShellScript
  [
    coreutils
    nix
    git
  ]
  ''
    export dream2nixSrc=${../../.}/src
    TESTDIR="$TMPDIR/tests/unit"
    mkdir -p $TESTDIR
    ln -sf ${framework.utils.scripts.nixFFI} "$TESTDIR/nix_ffi.py"
    cp -r ${self}/tests/unit/* $TESTDIR
    ${pythonEnv}/bin/pytest $TESTDIR -n $(nproc) -v "$@"
  ''
