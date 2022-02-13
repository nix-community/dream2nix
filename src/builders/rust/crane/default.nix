{
  lib,
  pkgs,

  externals,
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

  vendorPackageDependencies = import ../vendor.nix {
    inherit lib pkgs getSource getSourceSpec getDependencies getCyclicDependencies;
  };

  crane = externals.crane;

  buildPackage = pname: version:
    let
      override = produceDerivation pname;

      src = getSource pname version;
      vendorDir = vendorPackageDependencies pname version;

      deps = override (crane.buildDepsOnly {
        inherit pname version src;
        cargoVendorDir = vendorDir;
      });
    in
    override (crane.cargoBuild {
      inherit pname version src;
      cargoVendorDir = vendorDir;
      cargoArtifacts = deps;
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
