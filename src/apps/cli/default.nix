{
  # from dream2nix
  dream2nixWithExternals,
  externalSources,
  fetchers,
  translators,

  # from nixpkgs
  lib,
  python3,
  writeScript,
  ...
}:

let

  b = builtins;

  cliPython = python3.withPackages (ps: [ ps.networkx ps.cleo ]);

in
{
  program = writeScript "cli" ''
    dream2nixSrc=${dream2nixWithExternals} \
    fetcherNames="${b.toString (lib.attrNames fetchers.fetchers)}" \
      ${cliPython}/bin/python ${./cli.py} "$@"
  '';

  templateDefaultNix =
    {
      dream2nixLocationRelative,
    }:
    ''
      {
        dream2nix ? import ${dream2nixLocationRelative} {},
      }:

      (dream2nix.riseAndShine {
        dreamLock = ./dream.lock;
      }).package.overrideAttrs (old: {

      })
  '';
}
