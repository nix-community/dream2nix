{
  lib,
  pkgs,

  ...
}:

{
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
}@args:

let
  l = lib // builtins;

  utils = import ../utils.nix args;
  vendoring = import ../vendor.nix (args // { inherit lib pkgs utils; });

  buildPackage = pname: version:
    let
      src = utils.getRootSource pname version;
      vendorDir = vendoring.vendorDependencies pname version;

      cargoBuildFlags = "--package ${pname}";
    in
    produceDerivation pname (pkgs.rustPlatform.buildRustPackage {
      inherit pname version src;

      cargoBuildFlags = cargoBuildFlags;
      cargoCheckFlags = cargoBuildFlags;

      cargoVendorDir = "../nix-vendor";

      CARGO_HOME = "/build/.cargo-home";

      postUnpack = ''
        ln -s ${vendorDir} ./nix-vendor
      '';

      preConfigure = ''
        mkdir -p $CARGO_HOME
        mv /build/.cargo/config $CARGO_HOME/config.toml
        ${vendoring.writeGitVendorEntries "vendored-sources"}
      '';
    });
in
rec {
  packages =
    l.mapAttrs
      (name: version:
        { "${version}" = buildPackage name version; })
      args.packages;

  defaultPackage = packages."${defaultPackageName}"."${defaultPackageVersion}";
}
