{
  config,
  dream2nix,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.php-composer-lock;

  dreamLockUtils = import ../../flake-parts/lib/internal/dreamLockUtils.nix {inherit lib;};
  nodejsUtils = import ../../flake-parts/lib/internal/nodejsUtils.nix {inherit lib parseSpdxId;};
  parseSpdxId = import ../../flake-parts/lib/internal/parseSpdxId.nix {inherit lib;};
  prepareSourceTree = import ../../flake-parts/lib/internal/prepareSourceTree.nix {inherit lib;};
  simpleTranslate2 = import ../../flake-parts/lib/internal/simpleTranslate2.nix {inherit lib;};

  translate = import ./translate.nix {
    inherit lib dreamLockUtils nodejsUtils parseSpdxId simpleTranslate2;
  };

  dreamLock = translate {
    projectName = cfg.composerJson.name;
    projectRelPath = "";
    source = cfg.source;
    tree = prepareSourceTree {source = cfg.source;};
    noDev = ! cfg.withDevDependencies;
    # php = "unknown";
    inherit (cfg) composerJson composerLock;
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
  php-composer-lock = {
    inherit dreamLock;
    composerJson = l.fromJSON (l.readFile cfg.composerJsonFile);
    composerLock =
      if cfg.composerLockFile != null
      then l.fromJSON (l.readFile cfg.composerLockFile)
      else lib.mkDefault {};
  };
}
