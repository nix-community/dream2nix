{...}: {
  type = "ifd";
  build = {
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

    mkCrane = toolchain:
      if toolchain ? cargoHostTarget && toolchain ? cargoBuildBuild
      then externals.crane toolchain
      else if toolchain ? cargo
      then
        externals.crane {
          cargoHostTarget = toolchain.cargo;
          cargoBuildBuild = toolchain.cargo;
        }
      else throw "crane toolchain must include either a 'cargo' or both of 'cargoHostTarget' and 'cargoBuildBuild'";

    buildDepsWithToolchain =
      utils.mkBuildWithToolchain
      (toolchain: (mkCrane toolchain).buildDepsOnly);
    buildPackageWithToolchain =
      utils.mkBuildWithToolchain
      (toolchain: (mkCrane toolchain).buildPackage);
    defaultToolchain = {
      inherit (pkgs) cargo;
    };

    buildPackage = pname: version: let
      replacePaths =
        utils.replaceRelativePathsWithAbsolute
        subsystemAttrs.relPathReplacements.${pname}.${version};
      writeGitVendorEntries = vendoring.writeGitVendorEntries "nix-sources";

      # common args we use for both buildDepsOnly and buildPackage
      common = {
        inherit pname version;

        src = utils.getRootSource pname version;
        cargoVendorDir = "./nix-vendor";

        # this is needed because remove-references-to doesn't work on non nix-store paths
        doNotRemoveReferencesToVendorDir = true;

        postUnpack = ''
          export CARGO_HOME=$(pwd)/.cargo_home
        '';
        preConfigure = ''
          ${writeGitVendorEntries}
          ${replacePaths}
        '';

        # Make sure cargo only builds & tests the package we want
        cargoBuildCommand = "cargo build --release --package ${pname}";
        cargoTestCommand = "cargo test --release --package ${pname}";
      };

      # The deps-only derivation will use this as a prefix to the `pname`
      depsNameSuffix = "-deps";
      depsArgs =
        common
        // {
          # we pass cargoLock path to buildDepsOnly
          # so that crane's mkDummySrc adds it to the dummy source
          inherit (utils) cargoLock;
          pnameSuffix = depsNameSuffix;
          # Make sure cargo only checks the package we want
          cargoCheckCommand = "cargo check --release --package ${pname}";
          preUnpack = ''
            ${vendoring.copyVendorDir "$cargoVendorDir"}
          '';
          # move the vendored dependencies folder to $out for main derivation to use
          postInstall = ''
            mv $TMPDIR/nix-vendor $out/nix-vendor
          '';
        };
      deps =
        produceDerivation
        "${pname}${depsNameSuffix}"
        (buildDepsWithToolchain defaultToolchain depsArgs);

      buildArgs =
        common
        // {
          cargoArtifacts = deps;
          # link the vendor dir we used earlier to the correct place
          preUnpack = ''
            ln -sf ${deps}/nix-vendor $cargoVendorDir
          '';
          # write our cargo lock
          # note: we don't do this in buildDepsOnly since
          # that uses a cargoLock argument instead
          preConfigure = ''
            ${common.preConfigure}
            ${utils.writeCargoLock}
          '';
          passthru = {dependencies = deps;};
        };
    in
      produceDerivation
      pname
      (buildPackageWithToolchain defaultToolchain buildArgs);

    # TODO: this does not carry over environment variables from the
    # dependencies derivation. this could cause confusion for users.
    mkShellForPkg = pkg: let
      pkgDeps = pkg.passthru.dependencies;
    in
      pkg.overrideAttrs (old: {
        # we have to set these to empty because crane uses the phases
        # to compile & test. buildRustPackage uses hooks instead so that's
        # why build-rust-package doesn't need to do this.
        buildPhase = "";
        checkPhase = "";
        # we have to have some output, so we just record the build inputs
        # to a file (like mkShell does). this makes the derivation buildable.
        # see https://github.com/NixOS/nixpkgs/pull/153194.
        installPhase = "echo >> $out && export >> $out";

        # set cargo artifacts to empty string so that dependencies
        # derivation doesn't get built when entering devshell.
        cargoArtifacts = "";

        # merge build inputs from main drv and dependencies drv.
        buildInputs = l.unique (
          (old.buildInputs or [])
          ++ (pkgDeps.buildInputs or [])
          ++ [
            (
              pkg.passthru.rustToolchain.cargoHostTarget
              or pkg.passthru.rustToolchain.cargo
            )
          ]
        );
        nativeBuildInputs = l.unique (
          (old.nativeBuildInputs or [])
          ++ (pkgDeps.nativeBuildInputs or [])
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
