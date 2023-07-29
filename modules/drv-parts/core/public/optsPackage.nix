# Represents a package interface as proposed in:
#   https://github.com/NixOS/nix/issues/6507
{lib, ...}: let
  l = lib // builtins;
  t = l.types;
in {
  name = l.mkOption {
    type = t.str;
    description = "The name of the package";
  };
  meta = l.mkOption {
    type = t.attrs;
    default = {};
    description = "Extra attributes with meta information about the package";
  };
  outputs = l.mkOption {
    type = t.listOf t.str;
    description = ''A list of build outputs like "out" or "lib"'';
  };
  tests = l.mkOption {
    type = t.attrs;
    default = {};
    description = "A set of tests for the package";
  };
  version = l.mkOption {
    type = t.str;
    description = "The version of the package";
  };
}
