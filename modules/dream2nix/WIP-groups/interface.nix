{
  config,
  lib,
  specialArgs,
  ...
}: {
  options.groups = import ./groups-option.nix {
    inherit config lib specialArgs;
  };
}
