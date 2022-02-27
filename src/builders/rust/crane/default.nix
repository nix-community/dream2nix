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

  utils = import ../utils.nix args;
  vendoring = import ../vendor.nix (args // { inherit lib pkgs utils; });

  crane = externals.crane;

  buildPackage = pname: version:
    let
      src = utils.getRootSource pname version;
      cargoVendorDir = vendoring.vendorDependencies pname version;
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
