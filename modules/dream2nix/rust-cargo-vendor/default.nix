{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  cfg = config.rust-cargo-vendor;

  dreamLock = config.rust-cargo-lock.dreamLock;

  sourceRoot = config.mkDerivation.src;

  fetchDreamLockSources =
    import ../../../lib/internal/fetchDreamLockSources.nix
    {inherit lib;};
  getDreamLockSource = import ../../../lib/internal/getDreamLockSource.nix {inherit lib;};
  readDreamLock = import ../../../lib/internal/readDreamLock.nix {inherit lib;};
  hashPath = import ../../../lib/internal/hashPath.nix {
    inherit lib;
    inherit (config.deps) runCommandLocal nix;
  };
  hashFile = import ../../../lib/internal/hashFile.nix {
    inherit lib;
    inherit (config.deps) runCommandLocal nix;
  };

  # fetchers
  fetchers = {
    git = import ../../../lib/internal/fetchers/git {
      inherit hashPath;
      inherit (config.deps) fetchgit;
    };
    crates-io = import ../../../lib/internal/fetchers/crates-io {
      inherit hashFile;
      inherit (config.deps) fetchurl runCommandLocal;
    };
    path = import ../../../lib/internal/fetchers/path {
      inherit hashPath;
    };
  };

  dreamLockLoaded = readDreamLock {inherit dreamLock;};
  dreamLockInterface = dreamLockLoaded.interface;

  inherit (dreamLockInterface) defaultPackageName defaultPackageVersion;

  fetchedSources' = fetchDreamLockSources {
    inherit defaultPackageName defaultPackageVersion;
    inherit (dreamLockLoaded.lock) sources;
    inherit fetchers;
  };

  fetchedSources =
    fetchedSources'
    // {
      ${defaultPackageName}.${defaultPackageVersion} = sourceRoot;
    };

  getSource = getDreamLockSource fetchedSources;

  vendoring = import ./vendor.nix {
    inherit dreamLock getSource lib sourceRoot;
    inherit
      (dreamLockInterface)
      getSourceSpec
      getRoot
      subsystemAttrs
      ;
    inherit
      (config.deps)
      cargo
      jq
      moreutils
      python3Packages
      runCommandLocal
      writePython3
      ;
  };
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.core
  ];

  rust-cargo-vendor = {
    vendoredSources = vendoring.vendoredDependencies;
    inherit
      (vendoring)
      copyVendorDir
      getRootSource
      writeGitVendorEntries
      replaceRelativePathsWithAbsolute
      ;
  };

  deps = {nixpkgs, ...}:
    l.mapAttrs (_: l.mkOverride 998) {
      inherit
        (nixpkgs)
        cargo
        jq
        moreutils
        python3Packages
        runCommandLocal
        fetchurl
        fetchgit
        nix
        ;
      inherit
        (nixpkgs.writers)
        writePython3
        ;
    };
}
