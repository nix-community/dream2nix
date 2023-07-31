{
  config,
  lib,
  extendModules,
  ...
}: let
  l = lib // builtins;

  cfg = config.rust-crane;

  dreamLock = config.rust-cargo-lock.dreamLock;

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
      ${defaultPackageName}.${defaultPackageVersion} = config.mkDerivation.src;
    };

  getSource = getDreamLockSource fetchedSources;

  toTOML = import ../../../lib/internal/toTOML.nix {inherit lib;};

  utils = import ./utils.nix {
    inherit dreamLock getSource lib toTOML;
    inherit
      (dreamLockInterface)
      getSourceSpec
      getRoot
      subsystemAttrs
      packages
      ;
    inherit
      (config.deps)
      writeText
      ;
    sourceRoot = config.mkDerivation.src;
  };

  vendoring = import ./vendor.nix {
    inherit dreamLock getSource lib;
    inherit
      (dreamLockInterface)
      getSourceSpec
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

  allPackages = import ./build.nix {
    inherit lib utils vendoring cfg;
    inherit (dreamLockInterface) subsystemAttrs packages;
    inherit (config.deps) crane;
  };

  selectedPackage = allPackages.${config.name}.${config.version};
in {
  imports = [./interface.nix];

  public = lib.mkForce {
    type = "derivation";
    inherit config extendModules;
    inherit (config) name version;
    inherit
      (selectedPackage)
      drvPath
      outPath
      outputs
      outputName
      meta
      passthru
      ;
  };

  deps = {nixpkgs, ...}:
    (l.mapAttrs (_: l.mkDefault) {
      cargo = nixpkgs.cargo;
      craneSource = config.deps.fetchFromGitHub {
        owner = "ipetkov";
        repo = "crane";
        rev = "v0.12.2";
        sha256 = "sha256-looLH5MdY4erLiJw0XwQohGdr0fJL9y6TJY3898RA2U=";
      };
      crane = import ./crane.nix {
        inherit lib;
        inherit
          (config.deps)
          craneSource
          stdenv
          cargo
          jq
          zstd
          remarshal
          makeSetupHook
          writeText
          runCommand
          runCommandLocal
          ;
      };
    })
    # maybe it would be better to put these under `options.rust-crane.deps` instead of this `deps`
    # since it conflicts with a lot of stuff?
    // (l.mapAttrs (_: l.mkOverride 999) {
      inherit
        (nixpkgs)
        stdenv
        fetchurl
        jq
        zstd
        remarshal
        moreutils
        python3Packages
        makeSetupHook
        runCommandLocal
        runCommand
        writeText
        fetchFromGitHub
        ;
      inherit
        (nixpkgs.writers)
        writePython3
        ;
    });
}
