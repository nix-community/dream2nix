{
  lib,
  dream2nix,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.nodejs-node-builder-v3 = l.mapAttrs (_: l.mkOption) {
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
