{pkgs, ...}: let
  cliPython = pkgs.python3.withPackages (ps: [ps.cleo]);
in
  pkgs.writeScriptBin
  "contribute"
  ''
    dream2nixSrc=${../../.} \
      ${cliPython}/bin/python ${./contribute.py} contribute "$@"
  ''
