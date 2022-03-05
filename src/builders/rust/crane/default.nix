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
      preConfigure = ''
        ${vendoring.writeGitVendorEntries "nix-sources"}
      '';
      # The deps-only derivation will use this as a prefix to the `pname`
      depsNameSuffix = "-deps";
      # Make sure cargo only builds the package we want
      cargoExtraArgs = "--package ${pname}";
      # Set CARGO_HOME to /build because we write our .cargo/config there
      CARGO_HOME = "/build/.cargo_home";

      common = {inherit pname version src cargoVendorDir cargoExtraArgs preConfigure CARGO_HOME;};

      depsArgs = common // { pnameSuffix = depsNameSuffix; };
      deps = produceDerivation "${pname}${depsNameSuffix}" (crane.buildDepsOnly depsArgs);
      
      buildArgs = common // { cargoArtifacts = deps; };
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
