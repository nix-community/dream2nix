{
  # from nixpkgs
  python3,
  writeScript,
  ...
}: let
  cliPython = python3.withPackages (ps: [ps.cleo]);
in {
  program = writeScript "contribute" ''
    dream2nixSrc=${../../.} \
      ${cliPython}/bin/python ${./contribute.py} contribute "$@"
  '';
}
