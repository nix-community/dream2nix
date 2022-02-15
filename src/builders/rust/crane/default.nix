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

  vendoring = import ../vendor.nix {
    inherit lib pkgs getSource getSourceSpec
    getDependencies getCyclicDependencies subsystemAttrs;
  };

  crane = externals.crane;

  buildPackage = pname: version:
    let
      src = getSource pname version;
      cargoVendorDir = vendoring.vendorPackageDependencies pname version;
      preBuild = ''
        ${vendoring.writeGitVendorEntries "nix-sources"}
      '';
      # The deps-only derivation will use this as a prefix to the `pname`
      depsNameSuffix = "-deps";

      deps = produceDerivation "${pname}${depsNameSuffix}" (crane.buildDepsOnly {
        inherit pname version cargoVendorDir preBuild;
        pnameSuffix = depsNameSuffix;
        src =
          # This is needed because path dependencies will not contain a Cargo.lock
          # which are common when building from a git source that is a workspace.
          # crane expects a Cargo.lock *and* a Cargo.toml for a dependencies only build.
          if (lib.isAttrs source && source ? _generic && source ? _subsytem )
              || lib.hasSuffix "dream-lock.json" source then
            src
          else
            source;
      });
    in
    produceDerivation pname (crane.cargoBuild {
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
