{
  # from dream2nix
  externalSources,
  translators,

  # from nixpkgs
  python3,
  writeScript,
  ...
}:

let
  cliPython = python3.withPackages (ps: [ ps.networkx ps.cleo ]);
in

writeScript "cli" ''
  export d2nExternalSources=${externalSources}

  dream2nixSrc=${../../.} \
    ${cliPython}/bin/python ${./cli.py} "$@"
''
