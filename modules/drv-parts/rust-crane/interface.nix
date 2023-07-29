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
    };
    crane = {
      buildPackage = l.mkOption {
        type = t.functionTo t.package;
      };
      buildDepsOnly = l.mkOption {
        type = t.functionTo t.package;
      };
    };
  };

  options.rust-crane = {
  };
}
