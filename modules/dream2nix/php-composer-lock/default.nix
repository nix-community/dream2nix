{
  config,
  dream2nix,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.php-composer-lock;

  dreamLockUtils = import ../../../lib/internal/dreamLockUtils.nix {inherit lib;};
  nodejsUtils = import ../../../lib/internal/nodejsUtils.nix {inherit lib parseSpdxId;};
  parseSpdxId = import ../../../lib/internal/parseSpdxId.nix {inherit lib;};
  prepareSourceTree = import ../../../lib/internal/prepareSourceTree.nix {inherit lib;};
  simpleTranslate2 = import ../../../lib/internal/simpleTranslate2.nix {inherit lib;};

  translate = import ./translate.nix {
    inherit lib dreamLockUtils nodejsUtils parseSpdxId simpleTranslate2;
  };

  translate-cached = import ./translate-cached.nix {
    inherit lib simpleTranslate2;
  };

  # Dynamic translation (fallback when not using lock files)
  dynamicDreamLock = translate {
    projectName = cfg.composerJson.name;
    projectRelPath = "";
    source = cfg.source;
    tree = prepareSourceTree {source = cfg.source;};
    noDev = ! cfg.withDevDependencies;
    # php = "unknown";
    inherit (cfg) composerJson composerLock;
  };

  cachedDreamLock = translate-cached {
    projectRelPath = "";
    inherit (config.lock.content.fetchComposerMetadata) sources dependencies metadata;
  };

  # Use cached dreamLock when lock files are enabled, otherwise use dynamic
  dreamLock =
    if cfg.useLockFile
    then cachedDreamLock
    else dynamicDreamLock;

  writers = import ../../../pkgs/writers {
    inherit lib;
    inherit
      (config.deps)
      bash
      coreutils
      gawk
      path
      writeScript
      writeScriptBin
      ;
  };
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.core
  ];

  # declare external dependencies
  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      bash
      coreutils
      fetchgit
      fetchurl
      gawk
      nix
      path
      runCommandLocal
      writeScript
      writeScriptBin
      ;
    fetchComposerMetadataScript = import ../../../pkgs/fetchComposerMetadata/script.nix {
      inherit lib;
      inherit (config.deps) coreutils nix;
      inherit (nixpkgs) gitMinimal nix-prefetch-scripts openssh python3 writeText;
      inherit (config.paths) findRoot;
      inherit (writers) writePureShellScript;
      composerJsonPath = toString cfg.composerJsonFile;
      composerLockPath =
        if cfg.composerLockFile != null
        then toString cfg.composerLockFile
        else null;
      projectName = cfg.composerJson.name or config.name;
      noDev = ! cfg.withDevDependencies;
    };
  };

  # Keep composer metadata in lock file when using lock files
  lock.fields.fetchComposerMetadata = lib.mkIf cfg.useLockFile {
    script = config.deps.fetchComposerMetadataScript;
  };

  # if any of the invalidationData changes, the lock file will be invalidated
  #   and the user will be promted to re-generate it.
  lock.invalidationData = lib.mkIf cfg.useLockFile {
    composer = {
      # Hash of composer.lock content (or empty if no lock file)
      composerLockHash =
        if cfg.composerLockFile != null && l.pathExists cfg.composerLockFile
        then l.hashFile "sha256" cfg.composerLockFile
        else "";
      # Hash of composer.json content
      composerJsonHash = l.hashFile "sha256" cfg.composerJsonFile;
      # Include dev dependency setting
      withDevDependencies = cfg.withDevDependencies;
    };
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
