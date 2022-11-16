{
  self,
  lib,
  coreutils,
  nix,
  git,
  python3,
  dream2nixWithExternals,
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
    ${pythonEnv}/bin/pytest ${self}/tests/unit -n $(nproc) -v "$@"
  ''
