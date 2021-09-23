{
  # from nixpkgs
  python3,
  writeScript,
  ...
}:

let
  cliPython = python3.withPackages (ps: [ ps.cleo ]);
in

writeScript "cli" ''
  dream2nixSrc=${../../.} \
    ${cliPython}/bin/python ${./contribute.py} contribute "$@"
''
