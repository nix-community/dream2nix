{
  self,
  lib,
  nix,
  python3,
  utils,
  dream2nixWithExternals,
  ...
}: let
  l = lib // builtins;
in
  utils.writePureShellScript
  [
    nix
  ]
  ''
    export dream2nixSrc=${dream2nixWithExternals}
    ${python3.pkgs.pytest}/bin/pytest ${self}/tests/unit "$@"
  ''
