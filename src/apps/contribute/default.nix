{
  # from nixpkgs
  python3,
  writeScriptBin,
  ...
}: let
  cliPython = python3.withPackages (ps: [ps.cleo]);
in
  writeScriptBin
  "contribute"
  ''
    dream2nixSrc=${../../.} \
      ${cliPython}/bin/python ${./contribute.py} contribute "$@"
  ''
