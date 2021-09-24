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
  cliPython = python3.withPackages (ps: [ ps.networkx ]);
in

writeScript "cli" ''
  export d2nExternalSources=${externalSources}

  translatorsJsonFile=${translators.translatorsJsonFile} \
  dream2nixSrc=${../../.} \
    ${cliPython}/bin/python ${./cli.py} "$@"
''
