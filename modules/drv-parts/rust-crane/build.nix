{
  lib,
  crane,
  utils,
  vendoring,
  # lock data
  subsystemAttrs,
  packages,
  # config
  cfg,
  ...
}: let
  l = lib // builtins;

  buildPackage = pname: version: let
    replacePaths =
      utils.replaceRelativePathsWithAbsolute
      subsystemAttrs.relPathReplacements.${pname}.${version};
    writeGitVendorEntries = vendoring.writeGitVendorEntries "nix-sources";

    # common args we use for both buildDepsOnly and buildPackage
    common = {
      inherit pname version;

      src = utils.getRootSource pname version;
      cargoVendorDir = "$TMPDIR/nix-vendor";
      installCargoArtifactsMode = "use-zstd";

      postUnpack = ''
        export CARGO_HOME=$(pwd)/.cargo_home
        export cargoVendorDir="$TMPDIR/nix-vendor"
      '';
      preConfigure = ''
        ${writeGitVendorEntries}
        ${replacePaths}
      '';

      cargoBuildProfile = cfg.buildProfile;
      cargoTestProfile = cfg.testProfile;
      cargoBuildFlags = cfg.buildFlags;
      cargoTestFlags = cfg.testFlags;
      doCheck = cfg.runTests;

      # Make sure cargo only builds & tests the package we want
      cargoBuildCommand = "cargo build \${cargoBuildFlags:-} --profile \${cargoBuildProfile} --package ${pname}";
      cargoTestCommand = "cargo test \${cargoTestFlags:-} --profile \${cargoTestProfile} --package ${pname}";
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
        cargoCheckCommand = "cargo check \${cargoBuildFlags:-} --profile \${cargoBuildProfile} --package ${pname}";
        dream2nixVendorDir = vendoring.vendoredDependencies;
        preUnpack = ''
          ${vendoring.copyVendorDir "$dream2nixVendorDir" common.cargoVendorDir}
        '';
        # move the vendored dependencies folder to $out for main derivation to use
        postInstall = ''
          mv $TMPDIR/nix-vendor $out/nix-vendor
        '';
      };
    deps = crane.buildDepsOnly depsArgs;

    buildArgs =
      common
      // {
        meta = utils.getMeta pname version;
        cargoArtifacts = deps;
        # link the vendor dir we used earlier to the correct place
        preUnpack = ''
          ${vendoring.copyVendorDir "$cargoArtifacts/nix-vendor" common.cargoVendorDir}
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
    build = crane.buildPackage buildArgs;
  in
    build;

  allPackages =
    l.mapAttrs
    (name: version: {"${version}" = buildPackage name version;})
    packages;
in
  allPackages
