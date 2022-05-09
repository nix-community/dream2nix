{
  lib,
  pkgs,
  ...
} @ topArgs: {
  subsystemAttrs,
  defaultPackageName,
  defaultPackageVersion,
  getCyclicDependencies,
  getDependencies,
  getSource,
  getSourceSpec,
  packages,
  produceDerivation,
  ...
} @ args: let
  l = lib // builtins;

  utils = import ../utils.nix (args // topArgs);
  vendoring = import ../vendor.nix (args // topArgs);

  buildPackage = pname: version: let
    src = utils.getRootSource pname version;
    vendorDir = vendoring.vendoredDependencies;
    replacePaths = utils.replaceRelativePathsWithAbsolute {
      inherit src;
      paths = subsystemAttrs.relPathReplacements;
    };
    writeGitVendorEntries = vendoring.writeGitVendorEntries "vendored-sources";

    cargoBuildFlags = "--package ${pname}";
  in
    produceDerivation pname (pkgs.rustPlatform.buildRustPackage {
      inherit pname version src;

      cargoBuildFlags = cargoBuildFlags;
      cargoTestFlags = cargoBuildFlags;

      cargoVendorDir = "../nix-vendor";

      postUnpack = ''
        ln -s ${vendorDir} ./nix-vendor
        export CARGO_HOME=$(pwd)/.cargo_home
      '';

      preConfigure = ''
        mkdir -p $CARGO_HOME
        if [ -f ../.cargo/config ]; then
          mv ../.cargo/config $CARGO_HOME/config.toml
        fi
        ${writeGitVendorEntries}
        ${replacePaths}
      '';
    });
in rec {
  packages =
    l.mapAttrs
    (name: version: {"${version}" = buildPackage name version;})
    args.packages;

  defaultPackage = packages."${defaultPackageName}"."${defaultPackageVersion}";
}
