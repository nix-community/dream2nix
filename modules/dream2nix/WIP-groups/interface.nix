{
  config,
  lib,
  dream2nix,
  specialArgs,
  ...
}: let
  t = lib.types;
  groupType = t.submoduleWith {
    modules = [
      (import ./group.nix {
        inherit (config) overrideAll;
        overrides = config.overrides;
      })
    ];
    inherit specialArgs;
  };
in {
  options = {
    groups = lib.mkOption {
      type = t.lazyAttrsOf groupType;
      description = ''
        Holds multiple package sets (eg. groups).
        Holds shared config (overrideAll) and overrides on a global and on a per group basis.
      '';
    };
  };
}
