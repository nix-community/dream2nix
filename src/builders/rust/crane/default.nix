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
          # This is needed because path dependencies will not contain a Cargo.lock
          # which are common when building from a git source that is a workspace
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
