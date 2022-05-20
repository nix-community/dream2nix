{
  lib,
  pkgs,
  externals,
  ...
} @ topArgs: {
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
} @ args: let
  l = lib // builtins;

  utils = import ../utils.nix (args // topArgs);
  vendoring = import ../vendor.nix (args // topArgs);

  crane = externals.crane;

  buildPackage = pname: version: let
    _src = utils.getRootSource pname version;
    # patch the source so the cargo lock is written if it doesnt exist
    # we can't do this in preConfigure, crane fails
    src = pkgs.runCommandNoCC "${pname}-${version}-patched-src" {} ''
      mkdir -p $out
      cp -rv ${_src}/* $out
      cd $out
      ${utils.writeCargoLock}
    '';

    cargoVendorDir = vendoring.vendoredDependencies;
    replacePaths = utils.replaceRelativePathsWithAbsolute {
      paths = subsystemAttrs.relPathReplacements;
    };
    writeGitVendorEntries = vendoring.writeGitVendorEntries "nix-sources";

    postUnpack = ''
      export CARGO_HOME=$(pwd)/.cargo_home
    '';
    preConfigure = ''
      ${writeGitVendorEntries}
      ${replacePaths}
    '';

    common = {inherit pname version src cargoVendorDir preConfigure postUnpack;};

    # The deps-only derivation will use this as a prefix to the `pname`
    depsNameSuffix = "-deps";
    depsArgs = common // {pnameSuffix = depsNameSuffix;};
    deps = produceDerivation "${pname}${depsNameSuffix}" (crane.buildDepsOnly depsArgs);

    buildArgs =
      common
      // {
        cargoArtifacts = deps;
        # Make sure cargo only builds & tests the package we want
        cargoBuildCommand = "cargo build --release --package ${pname}";
        cargoTestCommand = "cargo test --release --package ${pname}";
      };
  in
    produceDerivation pname (crane.buildPackage buildArgs);
in rec {
  packages =
    l.mapAttrs
    (name: version: {"${version}" = buildPackage name version;})
    args.packages;

  defaultPackage = packages."${defaultPackageName}"."${defaultPackageVersion}";
}
