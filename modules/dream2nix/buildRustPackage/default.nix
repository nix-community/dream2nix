{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;

  readDreamLock = import ../../../lib/internal/readDreamLock.nix {inherit lib;};

  dreamLockLoaded =
    readDreamLock {inherit (config.rust-cargo-lock) dreamLock;};
  dreamLockInterface = dreamLockLoaded.interface;

  inherit
    (dreamLockInterface)
    subsystemAttrs # attrset
    ;

  meta = let
    meta = subsystemAttrs.meta.${pname}.${version};
  in
    meta
    // {
      license = l.map (name: l.licenses.${name}) meta.license;
    };

  pname = config.name;
  inherit (config) version;

  src = config.rust-cargo-vendor.getRootSource pname version;
  replacePaths =
    config.rust-cargo-vendor.replaceRelativePathsWithAbsolute
    subsystemAttrs.relPathReplacements.${pname}.${version};
  writeGitVendorEntries = config.rust-cargo-vendor.writeGitVendorEntries "vendored-sources";

  cargoBuildFlags = "--package ${pname}";
  buildArgs = {
    inherit pname version;
    src = lib.mkForce src;

    inherit meta;

    inherit cargoBuildFlags;
    cargoTestFlags = cargoBuildFlags;

    cargoVendorDir = "../nix-vendor";
    dream2nixVendorDir = config.rust-cargo-vendor.vendoredSources;

    postUnpack = ''
      ${config.rust-cargo-vendor.copyVendorDir "$dream2nixVendorDir" "./nix-vendor"}
      export CARGO_HOME=$(pwd)/.cargo_home
    '';

    preConfigure = ''
      mkdir -p $CARGO_HOME
      if [ -f ../.cargo/config ]; then
        mv ../.cargo/config $CARGO_HOME/config.toml
      fi
      ${writeGitVendorEntries}
      ${replacePaths}
      ${config.rust-cargo-lock.writeCargoLock}
    '';
  };
in {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.core
    ./interface.nix
  ];

  package-func.func = config.deps.rustPlatform.buildRustPackage;
  package-func.args = buildArgs;

  public = {
    inherit meta;
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      rustPlatform
      ;
  };
}
