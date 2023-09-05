{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  inherit (config.deps) fetchurl;

  nodejsLockUtils = import ../../../lib/internal/nodejsLockUtils.nix {inherit lib;};

  isLink = plent: plent ? link && plent.link;

  parseSource = plent:
    if isLink plent
    then
      # entry is local file
      (builtins.dirOf config.nodejs-package-lock-v3.packageLockFile) + "/${plent.resolved}"
    else
      fetchurl {
        url = plent.resolved;
        hash = plent.integrity;
      };

  getDependencies = lock: path: plent:
    l.mapAttrs (name: _descriptor: {
      dev = plent.dev or false;
      version = let
        # Need this util as dependencies no explizitly locked version
        # This findEntry is needed to find the exact locked version
        packageIdent = nodejsLockUtils.findEntry lock path name;
      in
        # Read version from package-lock entry for the resolved package
        lock.packages.${packageIdent}.version;
    })
    (plent.dependencies or {} // plent.devDependencies or {} // plent.optionalDependencies or {});

  # Takes one entry of "package" from package-lock.json
  parseEntry = lock: path: entry:
    if path == ""
    then {
      # Root level package
      name = entry.name;
      value = {
        ${entry.version} = {
          dependencies = getDependencies lock path entry;
        };
      };
    }
    else let
      source = parseSource entry;
      version =
        if isLink entry
        then let
          pjs = l.fromJSON (l.readFile (source + "/package.json"));
        in
          pjs.version
        else entry.version;
    in
      # Every other package
      {
        name = l.last (builtins.split "node_modules/" path);
        value = {
          ${version} = {
            dependencies = getDependencies lock path entry;
            inherit source;
          };
        };
      };

  parse = lock: (l.mapAttrs' (parseEntry lock) lock.packages);

  pdefs = parse config.nodejs-package-lock-v3.packageLock;
  # cfg = config.nodejs-package-lock-v3;
  # config.packageLock
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.core
  ];

  # declare external dependencies
  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchurl
      ;
  };

  nodejs-package-lock-v3.pdefs = pdefs;
}
