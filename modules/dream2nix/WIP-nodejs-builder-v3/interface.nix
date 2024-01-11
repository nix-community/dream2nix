{
  lib,
  dream2nix,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.WIP-nodejs-builder-v3 = l.mapAttrs (_: l.mkOption) {
    packageLockFile = {
      type = t.nullOr t.path;
      description = ''
        The package-lock.json file to use.
      '';
    };

    packageLock = {
      type = t.attrs;
      description = "The content of the package-lock.json";
    };

    trustedDeps = {
      type = t.listOf (t.str);
      default = [];
      example = ["@babel/core"];
      description = ''
        A list of trusted dependencies.

        If a dependency is trusted.
        Run the following scripts in order if present:

        > All versions of a dependency are trusted if there are multiple versions.

        preinstall
        install
        postinstall
        prepublish
        preprepare
        prepare
        postprepare

        The lifecycle scripts run only after node_modules are completely initialized with ALL dependencies.
        Lifecycle scripts can execute arbitrary code. Which makes them potentially insecure.
        They often violate isolation between packages. Which makes them potentially insecure.

        *TODO*:

        Trust all dependencies:

          trustedDeps [ "*" ]

        Trust all dependencies starting with "@org"

          trustedDeps [ "@org/*" ]

        which is usefull if you want to add all dependendencies within an organization.
      '';
    };

    inherit
      (import ./types.nix {
        inherit
          lib
          dream2nix
          specialArgs
          ;
      })
      pdefs
      fileSystem
      ;
  };
}
