{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
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
    # TODO: use mkDerivation module interface here
    mainDrvOptions = {
      type = t.submodule {
        freeformType = t.attrsOf t.raw;
      };
      description = "Attributes to pass to the buildPackage function";
      default = {};
    };
    # TODO: use mkDerivation module interface here
    depsDrvOptions = {
      type = t.submodule {
        freeformType = t.attrsOf t.raw;
      };
      description = "Attributes to pass to the buildDepsOnly function";
      default = {};
    };
  };
}
