{
  lib,
  dlib,
  pkgs,
  externals,
  ...
} @ topArgs: {
  type = "pure";

  build = {
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

    buildWithToolchain =
      utils.mkBuildWithToolchain
      (toolchain: (pkgs.makeRustPlatform toolchain).buildRustPackage);
    defaultToolchain = {
      inherit (pkgs) cargo rustc;
    };

    buildPackage = pname: version: let
      src = utils.getRootSource pname version;
      replacePaths =
        utils.replaceRelativePathsWithAbsolute
        subsystemAttrs.relPathReplacements.${pname}.${version};
      writeGitVendorEntries = vendoring.writeGitVendorEntries "vendored-sources";

      cargoBuildFlags = "--package ${pname}";
      buildArgs = {
        inherit pname version src;

        meta = utils.getMeta pname version;

        cargoBuildFlags = cargoBuildFlags;
        cargoTestFlags = cargoBuildFlags;

        cargoVendorDir = "../nix-vendor";
        dream2nixVendorDir = vendoring.vendoredDependencies;

        postUnpack = ''
          ${vendoring.copyVendorDir "$dream2nixVendorDir" "./nix-vendor"}
          export CARGO_HOME=$(pwd)/.cargo_home
        '';

        preConfigure = ''
          mkdir -p $CARGO_HOME
          if [ -f ../.cargo/config ]; then
            mv ../.cargo/config $CARGO_HOME/config.toml
          fi
          ${writeGitVendorEntries}
          ${replacePaths}
          ${utils.writeCargoLock}
        '';
      };
    in
      produceDerivation pname (buildWithToolchain {
        toolchain = defaultToolchain;
        args = buildArgs;
      });

    allPackages =
      l.mapAttrs
      (name: version: {"${version}" = buildPackage name version;})
      args.packages;

    allPackagesList =
      l.mapAttrsToList
      (name: version: allPackages.${name}.${version})
      args.packages;
    shell = pkgs.callPackage ../devshell.nix {
      name = "devshell";
      drvs = allPackagesList;
    };
  in {
    packages = allPackages;
    devShells = {
      default = shell;
    };
  };
}
