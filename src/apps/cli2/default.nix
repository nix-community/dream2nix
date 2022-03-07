{
  # from dream2nix
  configFile,
  dream2nixWithExternals,
  fetchers,
  nix,
  translators,
  utils,
  # from nixpkgs
  gitMinimal,
  lib,
  python3,
  ...
}: let
  b = builtins;

  cliPython = python3.withPackages (ps: [ps.networkx ps.cleo ps.jsonschema]);
in {
  program =
    utils.writePureShellScript
    [
      gitMinimal
      nix
    ]
    ''
      # escape the temp dir created by writePureShellScript
      cd - > /dev/null

      # run the cli
      dream2nixConfig=${configFile} \
      dream2nixSrc=${dream2nixWithExternals} \
      fetcherNames="${b.toString (lib.attrNames fetchers.fetchers)}" \
        ${cliPython}/bin/python ${./.}/cli.py "$@"
    '';

  templateDefaultNix = {
    dream2nixLocationRelative,
    dreamLock,
    sourcePathRelative,
  }: let
    defaultPackage = dreamLock._generic.defaultPackage;
    defaultPackageVersion = dreamLock._generic.packages."${defaultPackage}";
  in ''
    {
      dream2nix ? import (
        let
          dream2nixWithExternals = (builtins.getEnv "dream2nixWithExternals");
        in
          if dream2nixWithExternals != "" then dream2nixWithExternals else
            throw '''
              This default.nix is for debugging purposes and can only be evaluated within the dream2nix devShell env.
            ''') {},
    }:

    dream2nix.makeOutputs {
      source = ./dream-lock.json;
      ${lib.optionalString (dreamLock.sources."${defaultPackage}"."${defaultPackageVersion}".type == "unknown") ''
      sourceOverrides = oldSources: {
          "${defaultPackage}"."${defaultPackageVersion}" = ./${sourcePathRelative};
        };
    ''}
    }
  '';
}
