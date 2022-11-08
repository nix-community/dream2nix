{pkgs, ...}: let
  cliPython = pkgs.python3.withPackages (ps: []);
in
  pkgs.writeScriptBin
  "replaceRootSources"
  ''
    ${cliPython}/bin/python ${./replaceRootSources.py} "$@"
  ''
