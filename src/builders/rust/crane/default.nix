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
      postUnpack = ''
        export CARGO_HOME=$(pwd)/.cargo_home
      '';
      preConfigure = ''
        ${vendoring.writeGitVendorEntries "nix-sources"}
      '';
      # The deps-only derivation will use this as a prefix to the `pname`
      depsNameSuffix = "-deps";

      common = {inherit pname version src cargoVendorDir preConfigure postUnpack;};

      depsArgs = common // { pnameSuffix = depsNameSuffix; };
      deps = produceDerivation "${pname}${depsNameSuffix}" (crane.buildDepsOnly depsArgs);
      
      buildArgs = common // {
        cargoArtifacts = deps;
        # Make sure cargo only builds & tests the package we want
        cargoBuildCommand = "cargo build --release --package ${pname}";
        cargoTestCommand = "cargo test --release --package ${pname}";
      };
    in
    produceDerivation pname (crane.buildPackage buildArgs);
in
rec {
  packages =
    l.mapAttrs
      (name: version:
        { "${version}" = buildPackage name version; })
      args.packages;

  defaultPackage = packages."${defaultPackageName}"."${defaultPackageVersion}";
}
