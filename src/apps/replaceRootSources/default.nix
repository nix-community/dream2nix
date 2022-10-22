{
  # from nixpkgs
  python3,
  writeScriptBin,
  ...
}: let
  cliPython = python3.withPackages (ps: []);
in
  writeScriptBin
  "replaceRootSources"
  ''
    ${cliPython}/bin/python ${./replaceRootSources.py} "$@"
  ''
