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

  vendoring = import ../vendor.nix {
    inherit lib pkgs getSource getSourceSpec
    getDependencies getCyclicDependencies subsystemAttrs;
  };

  getRootSource = import ../getRootSource.nix {
    inherit getSource getSourceSpec;
  };

  buildPackage = pname: version:
    let
      src = getRootSource pname version;
      vendorDir = vendoring.vendorPackageDependencies pname version;

      cargoBuildFlags = "--package ${pname}";
    in
    produceDerivation pname (pkgs.rustPlatform.buildRustPackage {
      inherit pname version src;

      cargoBuildFlags = cargoBuildFlags;
      cargoCheckFlags = cargoBuildFlags;

      cargoVendorDir = "../nix-vendor";

      postUnpack = ''
        ln -s ${vendorDir} ./nix-vendor
      '';

      preBuild = ''
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
