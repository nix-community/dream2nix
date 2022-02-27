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

  vendoring = import ../vendor.nix {
    inherit lib pkgs getSource getSourceSpec
    getDependencies getCyclicDependencies subsystemAttrs;
  };

  getRootSource = import ../getRootSource.nix {
    inherit getSource getSourceSpec;
  };

  crane = externals.crane;

  buildPackage = pname: version:
    let
      src = getRootSource pname version;
      cargoVendorDir = vendoring.vendorPackageDependencies pname version;
      preBuild = ''
        ${vendoring.writeGitVendorEntries "nix-sources"}
      '';
      # The deps-only derivation will use this as a prefix to the `pname`
      depsNameSuffix = "-deps";

      deps = produceDerivation "${pname}${depsNameSuffix}" (crane.buildDepsOnly {
        inherit pname version src cargoVendorDir preBuild;
        pnameSuffix = depsNameSuffix;
      });
    in
    produceDerivation pname (crane.buildPackage {
      inherit pname version src cargoVendorDir preBuild;
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
