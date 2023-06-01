{
  config,
  lib,
  ...
} @ topArgs: let
  l = lib // builtins;

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
    http = import ../../../lib/internal/fetchers/http {
      inherit hashFile lib;
      inherit (config.deps.stdenv) mkDerivation;
      inherit (config.deps) fetchurl;
    };
    crates-io = import ../../../lib/internal/fetchers/crates-io {
      inherit hashFile;
      inherit (config.deps) fetchurl runCommandLocal;
    };
  };

  dreamLockLoaded =
    readDreamLock {inherit (config.rust-cargo-lock) dreamLock;};
  dreamLockInterface = dreamLockLoaded.interface;

  fetchedSources' = fetchDreamLockSources {
    inherit (dreamLockInterface) defaultPackageName defaultPackageVersion;
    inherit (dreamLockLoaded.lock) sources;
    inherit fetchers;
  };

  fetchedSources =
    fetchedSources'
    // {
      ${defaultPackageName}.${defaultPackageVersion} = config.mkDerivation.src;
    };

  # name: version: -> store-path
  getSource = getDreamLockSource fetchedSources;

  inherit
    (dreamLockInterface)
    getDependencies # name: version: -> [ {name=; version=; } ]
    # Attributes
    
    subsystemAttrs # attrset
    packageVersions
    defaultPackageName
    defaultPackageVersion
    ;

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

  buildWithToolchain =
    utils.mkBuildWithToolchain
    (toolchain: (config.deps.makeRustPlatform toolchain).buildRustPackage);

  defaultToolchain = {
    inherit (config.deps) cargo rustc;
  };

  buildPackage = pname: version: let
    src = utils.getRootSource pname version;
    replacePaths =
      utils.replaceRelativePathsWithAbsolute
      subsystemAttrs.relPathReplacements.${pname}.${version};
    writeGitVendorEntries = vendoring.writeGitVendorEntries "vendored-sources";

    cargoBuildFlags = "--package ${pname}";
    buildArgs = {
      inherit pname version src;

      meta = utils.getMeta pname version;

      cargoBuildFlags = cargoBuildFlags;
      cargoTestFlags = cargoBuildFlags;

      cargoVendorDir = "../nix-vendor";
      dream2nixVendorDir = vendoring.vendoredDependencies;

      postUnpack = ''
        ${vendoring.copyVendorDir "$dream2nixVendorDir" "./nix-vendor"}
        export CARGO_HOME=$(pwd)/.cargo_home
      '';

      preConfigure = ''
        mkdir -p $CARGO_HOME
        if [ -f ../.cargo/config ]; then
          mv ../.cargo/config $CARGO_HOME/config.toml
        fi
        ${writeGitVendorEntries}
        ${replacePaths}
        ${utils.writeCargoLock}
      '';
    };
  in
    buildWithToolchain {
      toolchain = defaultToolchain;
      args = buildArgs;
    };

  allPackages =
    l.mapAttrs
    (name: version: {"${version}" = buildPackage name version;})
    dreamLockInterface.packages;

  mkShellForDrvs = drvs:
    import ./devshell.nix {
      inherit drvs lib;
      inherit (config.deps) mkShell;
      name = "devshell";
    };

  pkgShells =
    l.mapAttrs
    (
      name: version: let
        pkg = allPackages.${name}.${version};
      in
        mkShellForDrvs [pkg]
    )
    dreamLockInterface.packages;

  allPackagesList =
    l.mapAttrsToList
    (name: version: allPackages.${name}.${version})
    dreamLockInterface.packages;

  packages = allPackages;

  devShells =
    pkgShells
    // {
      default = mkShellForDrvs allPackagesList;
    };
in {
  imports = [
    # dream2nix.modules.drv-parts.mkDerivation
  ];

  public = lib.mkForce packages.${dreamLockInterface.defaultPackageName}.${dreamLockInterface.defaultPackageVersion};

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      cargo
      fetchurl
      jq
      makeRustPlatform
      moreutils
      python3Packages
      runCommandLocal
      rustc
      ;
    inherit
      (nixpkgs.writers)
      writePython3
      ;
  };
}
