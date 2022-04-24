{
  self,
  lib,
  coreutils,
  nix,
  python3,
  utils,
  dream2nixWithExternals,
  ...
}: let
  l = lib // builtins;

  pythonEnv = python3.withPackages (ps:
    with ps; [
      pytest
      pytest-xdist
    ]);
in
  utils.writePureShellScript
  [
    coreutils
    nix
  ]
  ''
    export dream2nixSrc=${dream2nixWithExternals}
    ${pythonEnv}/bin/pytest ${self}/tests/unit -n $(nproc) -v "$@"
  ''
