{
  config,
  lib,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.pdm = {
    lockfile = l.mkOption {
      type = t.path;
    };
    pyproject = l.mkOption {
      type = t.path;
    };

    sourceSelector = import ./sourceSelectorOption.nix {inherit lib;};
  };
  options.groups =
    (import ../WIP-groups/groups-option.nix {inherit config lib specialArgs;})
    // {
      internal = true;
      visible = "shallow";
    };
}
