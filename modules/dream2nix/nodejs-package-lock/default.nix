{
  config,
  dream2nix,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.nodejs-package-lock;

  nodejsUtils = import ../../../lib/internal/nodejsUtils.nix {inherit lib parseSpdxId;};
  parseSpdxId = import ../../../lib/internal/parseSpdxId.nix {inherit lib;};
  prepareSourceTree = import ../../../lib/internal/prepareSourceTree.nix {inherit lib;};
  simpleTranslate = import ../../../lib/internal/simpleTranslate.nix {inherit lib;};

  translate = import ./translate.nix {
    inherit lib nodejsUtils parseSpdxId simpleTranslate;
  };

  dreamLock = translate {
    projectName = config.name;
    projectRelPath = "";
    workspaces = [];
    workspaceParent = "";
    source = cfg.src;
    tree = prepareSourceTree {source = cfg.source;};
    noDev = ! cfg.withDevDependencies;
    nodejs = "unknown";
    inherit (cfg) packageJson packageLock;
  };
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.mkDerivation
  ];

  # declare external dependencies
  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchgit
      fetchurl
      nix
      runCommandLocal
      ;
  };
  nodejs-package-lock = {
    inherit dreamLock;
    packageJson = l.fromJSON (l.readFile cfg.packageJsonFile);
    packageLock =
      if cfg.packageLockFile != null
      then l.fromJSON (l.readFile cfg.packageLockFile)
      else lib.mkDefault {};
  };
}
