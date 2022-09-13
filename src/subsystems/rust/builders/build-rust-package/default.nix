{...}: {
  type = "pure";

  build = {
    lib,
    dlib,
    pkgs,
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
    in
      produceDerivation pname (buildWithToolchain defaultToolchain {
        inherit pname version src;

        meta = utils.getMeta pname version;

        cargoBuildFlags = cargoBuildFlags;
        cargoTestFlags = cargoBuildFlags;

        cargoVendorDir = "../nix-vendor";

        postUnpack = ''
          ${vendoring.copyVendorDir "./nix-vendor"}
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
      });

    mkShellForPkg = pkg:
      pkg.overrideAttrs (old: {
        buildInputs =
          (old.buildInputs or [])
          ++ (
            with pkg.passthru.rustToolchain; [
              cargo
              rustc
            ]
          );
      });

    allPackages =
      l.mapAttrs
      (name: version: {"${version}" = buildPackage name version;})
      args.packages;

    allDevshells =
      l.mapAttrs
      (name: version: mkShellForPkg allPackages.${name}.${version})
      args.packages;
  in {
    packages = allPackages;
    devShells =
      allDevshells
      // {
        default = allDevshells.${defaultPackageName};
      };
  };
}
