{
  lib,
  dream2nix,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.deps = {
    crane = l.mkOption {
      type = t.attrs;
      readOnly = true;
      description = "The crane lib that was instantiated from `craneSource`";
    };
    craneSource = l.mkOption {
      type = t.path;
      description = "Source to use for crane functions";
    };
    mkRustToolchain = l.mkOption {
      type = t.functionTo t.package;
      description = "Function to call that returns a rust toolchain using the provided nixpkgs instance";
    };
  };

  options.rust-crane = l.mapAttrs (_: l.mkOption) {
    runTests = {
      type = t.bool;
      description = "Whether to run tests via `cargo test`";
      default = true;
    };
    checkCommand = {
      type = t.str;
      description = "The cargo subcommand to use when checking the crate (instead of 'check' in 'cargo check')";
      default = "check";
      example = "clippy";
    };
    buildCommand = {
      type = t.str;
      description = "The cargo subcommand to use when building the crate (instead of 'build' in 'cargo build')";
      default = "build";
    };
    buildProfile = {
      type = t.str;
      description = "The profile to use when building & checking";
      default = "release";
    };
    buildFlags = {
      type = t.listOf t.str;
      description = "Flags to add when building & checking";
      default = [];
    };
    testCommand = {
      type = t.str;
      description = "The cargo subcommand to use when testing the crate (instead of 'test' in 'cargo test')";
      default = "test";
    };
    testProfile = {
      type = t.str;
      description = "The profile to use when testing the crate";
      default = "release";
    };
    testFlags = {
      type = t.listOf t.str;
      description = "Flags to add when testing the crate";
      default = [];
    };
    testFlagsExtra = {
      type = t.str;
      description = "additional flags to be passed in the cargoTestCommand invocation";
      default = "--no-run";
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
