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
  source,

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
      src = getSource pname version;
      vendorDir = vendorPackageDependencies pname version;

      deps = produceDerivation "${pname}-deps" (crane.buildDepsOnly {
        inherit pname version;
        src =
          if (lib.isAttrs source && source ? _generic && source ? _subsytem )
              || lib.hasSuffix "dream-lock.json" source then
            src
          else
            source;
        cargoVendorDir = vendorDir;
      });
    in
    produceDerivation pname (crane.cargoBuild {
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
