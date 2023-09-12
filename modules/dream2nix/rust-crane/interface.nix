{
  lib,
  dream2nix,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.public = {
    devShell = l.mkOption {
      type = t.package;
      description = "Development shell for this package";
    };
    dependencies = l.mkOption {
      type = t.package;
      description = "The dependencies derivation for this package";
    };
  };

  options.deps = {
    cargo = l.mkOption {
      type = t.package;
      description = "The Cargo package to use";
    };
    craneSource = l.mkOption {
      type = t.path;
      description = "Source to use for crane functions";
    };
    crane = {
      buildPackage = l.mkOption {
        type = t.functionTo t.package;
        description = "The function to use when building packages";
      };
      buildDepsOnly = l.mkOption {
        type = t.functionTo t.package;
        description = "The function to use when building dependencies of a package";
      };
    };
  };

  options.rust-crane = l.mapAttrs (_: l.mkOption) {
    source = {
      type = t.path;
      description = "The source of a Cargo package or workspace to use when building";
    };
    runTests = {
      type = t.bool;
      description = "Whether to run tests via `cargo test`";
      default = true;
    };
    buildProfile = {
      type = t.str;
      description = "The profile to use when running `cargo build` and `cargo check`";
      default = "release";
    };
    testProfile = {
      type = t.str;
      description = "The profile to use when running `cargo test`";
      default = "release";
    };
    buildFlags = {
      type = t.listOf t.str;
      description = "Flags to add when running `cargo build` and `cargo check`";
      default = [];
    };
    testFlags = {
      type = t.listOf t.str;
      description = "Flags to add when running `cargo test`";
      default = [];
    };
    mainDrv = {
      type = t.submoduleWith {
        modules = [dream2nix.modules.dream2nix.mkDerivation];
        inherit specialArgs;
      };
      description = "The main derivation config that builds the package";
      default = {};
    };
    depsDrv = {
      type = t.submoduleWith {
        modules = [dream2nix.modules.dream2nix.mkDerivation];
        inherit specialArgs;
      };
      description = "A single derivation with all dependencies of the package";
      default = {};
    };
  };
}
