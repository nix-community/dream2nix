{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;

  cfg = config.rust-crane;

  dreamLock = config.rust-cargo-lock.dreamLock;

  readDreamLock = import ../../../lib/internal/readDreamLock.nix {inherit lib;};

  dreamLockLoaded = readDreamLock {inherit dreamLock;};
  dreamLockInterface = dreamLockLoaded.interface;

  meta = let
    meta = dreamLockInterface.subsystemAttrs.meta.${pname}.${version};
  in
    meta
    // {
      license = l.map (name: l.licenses.${name}) meta.license;
    };

  _crane = import config.deps.craneSource {
    pkgs = config.deps.cranePkgs;
  };
  crane = _crane.overrideToolchain config.deps.mkRustToolchain;
  rustToolchain = config.deps.mkRustToolchain config.deps.cranePkgs;

  pname = config.name;
  version = config.version;

  replacePaths =
    config.rust-cargo-vendor.replaceRelativePathsWithAbsolute
    dreamLockInterface.subsystemAttrs.relPathReplacements.${pname}.${version};
  writeGitVendorEntries = config.rust-cargo-vendor.writeGitVendorEntries "nix-sources";

  # common args we use for both buildDepsOnly and buildPackage
  common = {
    src = lib.mkForce (config.rust-cargo-vendor.getRootSource pname version);
    postUnpack = ''
      export CARGO_HOME=$(pwd)/.cargo_home
      export cargoVendorDir="$TMPDIR/nix-vendor"
    '';
    preConfigure = ''
      ${writeGitVendorEntries}
      ${replacePaths}
    '';
    inherit pname version;

    cargoVendorDir = "$TMPDIR/nix-vendor";
    installCargoArtifactsMode = "use-zstd";

    checkCargoCommand = cfg.checkCommand;
    buildCargoCommand = cfg.buildCommand;
    cargoBuildProfile = cfg.buildProfile;
    cargoBuildFlags = cfg.buildFlags;
    testCargoCommand = cfg.testCommand;
    cargoTestProfile = cfg.testProfile;
    cargoTestFlags = cfg.testFlags;
    doCheck = cfg.runTests;

    # Make sure cargo only checks & builds & tests the package we want
    cargoCheckCommand = "cargo \${checkCargoCommand} \${cargoBuildFlags:-} --profile \${cargoBuildProfile} --package ${pname}";
    cargoBuildCommand = "cargo \${buildCargoCommand} \${cargoBuildFlags:-} --profile \${cargoBuildProfile} --package ${pname}";
    cargoTestCommand = "cargo \${testCargoCommand} \${cargoTestFlags:-} --profile \${cargoTestProfile} --package ${pname}";
  };

  # The deps-only derivation will use this as a prefix to the `pname`
  depsNameSuffix = "-deps";
  depsArgs = {
    preUnpack = ''
      ${config.rust-cargo-vendor.copyVendorDir "$dream2nixVendorDir" common.cargoVendorDir}
    '';
    # move the vendored dependencies folder to $out for main derivation to use
    postInstall = ''
      mv $TMPDIR/nix-vendor $out/nix-vendor
    '';
    # we pass cargoLock path to buildDepsOnly
    # so that crane's mkDummySrc adds it to the dummy source
    inherit (config.rust-cargo-lock) cargoLock;
    pname = l.mkOverride 99 pname;
    pnameSuffix = depsNameSuffix;
    dream2nixVendorDir = config.rust-cargo-vendor.vendoredSources;
  };

  buildArgs = {
    # link the vendor dir we used earlier to the correct place
    preUnpack = ''
      ${config.rust-cargo-vendor.copyVendorDir "$cargoArtifacts/nix-vendor" common.cargoVendorDir}
    '';
    # write our cargo lock
    # note: we don't do this in buildDepsOnly since
    # that uses a cargoLock argument instead
    preConfigure = l.mkForce ''
      ${common.preConfigure}
      ${config.rust-cargo-lock.writeCargoLock}
    '';
    cargoArtifacts = cfg.depsDrv.public;
  };
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.core
  ];

  rust-crane.depsDrv = {
    inherit version;
    name = pname + depsNameSuffix;
    package-func.func = crane.buildDepsOnly;
    package-func.args = l.mkMerge [
      common
      depsArgs
    ];
  };

  package-func.func = crane.buildPackage;
  package-func.args = l.mkMerge [common buildArgs];

  public = {
    devShell = import ./devshell.nix {
      name = "${pname}-devshell";
      depsDrv = cfg.depsDrv.public;
      mainDrv = config.public;
      inherit lib;
      inherit (config.deps) libiconv mkShell;
      cargo = rustToolchain;
    };
    dependencies = cfg.depsDrv.public;
    meta = meta // config.mkDerivation.meta;
  };

  deps = {nixpkgs, ...}:
    l.mkMerge [
      {
        # override cargo package to be the rust toolchain so that rust-cargo-vendor uses the custom provided toolchain if any
        cargo = l.mkOverride 1001 rustToolchain;
      }
      (l.mapAttrs (_: l.mkDefault) {
        inherit crane;
        craneSource = config.deps.fetchFromGitHub {
          owner = "ipetkov";
          repo = "crane";
          rev = "v0.19.0";
          sha256 = "sha256-/mumx8AQ5xFuCJqxCIOFCHTVlxHkMT21idpbgbm/TIE=";
        };
        cranePkgs = nixpkgs.pkgs;
        mkRustToolchain = pkgs: pkgs.cargo;
      })
      (l.mapAttrs (_: l.mkOverride 999) {
        inherit
          (nixpkgs)
          mkShell
          libiconv
          fetchFromGitHub
          ;
      })
    ];
}
