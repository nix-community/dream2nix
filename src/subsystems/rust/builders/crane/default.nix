let
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

    crane = externals.crane;

    buildPackage = pname: version: let
      replacePaths = utils.replaceRelativePathsWithAbsolute {
        paths = subsystemAttrs.relPathReplacements;
      };
      writeGitVendorEntries = vendoring.writeGitVendorEntries "nix-sources";

      # common args we use for both buildDepsOnly and buildPackage
      common = {
        inherit pname version;
        src = utils.getRootSource pname version;
        cargoVendorDir = vendoring.vendoredDependencies;
        postUnpack = ''
          export CARGO_HOME=$(pwd)/.cargo_home
        '';
        preConfigure = ''
          ${writeGitVendorEntries}
          ${replacePaths}
        '';
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
        };
      deps = produceDerivation "${pname}${depsNameSuffix}" (crane.buildDepsOnly depsArgs);

      buildArgs =
        common
        // {
          cargoArtifacts = deps;
          # Make sure cargo only builds & tests the package we want
          cargoBuildCommand = "cargo build --release --package ${pname}";
          cargoTestCommand = "cargo test --release --package ${pname}";
          # write our cargo lock
          # note: we don't do this in buildDepsOnly since
          # that uses a cargoLock argument instead
          preConfigure = ''
            ${common.preConfigure}
            ${utils.writeCargoLock}
          '';
        };
    in
      produceDerivation pname (crane.buildPackage buildArgs);
  in rec {
    packages =
      l.mapAttrs
      (name: version: {"${version}" = buildPackage name version;})
      args.packages;

    defaultPackage = packages."${defaultPackageName}"."${defaultPackageVersion}";
  };
in
  {...}: {
    type = "ifd";
    inherit build;
  }
