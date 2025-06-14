{
  config,
  lib,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
  mkSubmodule = import ../../../lib/internal/mkSubmodule.nix {inherit lib specialArgs;};
in {
  options.pdm = mkSubmodule {
    imports = [
      ../overrides
      ../python-editables
    ];
    options = {
      lockfile = l.mkOption {
        type = t.path;
      };
      pyproject = l.mkOption {
        type = t.path;
      };
      useUvResolver = l.mkOption {
        type = t.bool;
        default = false;
      };
      group = l.mkOption {
        type = t.str;
        default = "default";
      };

      sourceSelector = import ./sourceSelectorOption.nix {inherit lib;};
    };
  };
  options.groups =
    (import ../WIP-groups/groups-option.nix {inherit config lib specialArgs;})
    // {
      internal = true;
      visible = "shallow";
    };
}
