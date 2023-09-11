{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  cfg = config.nodejs-package-lock-v3;

  inherit (config.deps) fetchurl;

  nodejsLockUtils = import ../../../lib/internal/nodejsLockUtils.nix { inherit lib; };

  # Collection of sanitized functions that always return the same type
  isLink = pent: pent.link or false;

  # isDev = pent: pent.dev or false;
  # isOptional = pent: pent.optional or false;
  # isInBundle = pent: pent.inBundle or false;
  # hasInstallScript = pent: pent.hasInstallScript or false;
  # getBin = pent: pent.bin or {};

  /*
    Pent :: {
      See: https://docs.npmjs.com/cli/v9/configuring-npm/package-lock-json#packages
    }
    pent is one entry of 'packages'
  */
  parseSource = pent:
    if isLink pent
    then
      # entry is local file
      (builtins.dirOf config.nodejs-package-lock-v3.packageLockFile) + "/${pent.resolved}"
    else
      fetchurl {
        url = pent.resolved;
        hash = pent.integrity;
      };


  getDependencies = lock: path: pent:
    l.mapAttrs (depName: _semverConstraint: 
    let
      packageIdent = nodejsLockUtils.findEntry lock path depName;
      depPent = lock.packages.${packageIdent};
    in
    {
      dev = pent.dev or false;
      version = depPent.version;
    })
    (pent.dependencies or {} // pent.devDependencies or {} // pent.optionalDependencies or {});


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

  mergePdefs = builtins.foldl'
    (acc: entry:
      acc
      // {
        ${entry.name} = acc.${entry.name} or {} // entry.value;
      })
    {};

  parse = lock:
    mergePdefs
    # type: [ { name :: String; value :: {...}; } ]
    (l.mapAttrsToList (parseEntry lock) lock.packages);

  pdefs = parse config.nodejs-package-lock-v3.packageLock;
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
  nodejs-package-lock-v3.packageLock =
    lib.mkDefault
    (builtins.fromJSON (builtins.readFile cfg.packageLockFile));
}
