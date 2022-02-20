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

  buildPackage = pname: version:
    let
      src = getSource pname version;
      vendorDir = vendoring.vendorPackageDependencies pname version;
    in
    produceDerivation pname (pkgs.rustPlatform.buildRustPackage {
      inherit pname version src;

      postUnpack = ''
        ln -s ${vendorDir} ./nix-vendor
      '';

      cargoVendorDir = "../nix-vendor";

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
