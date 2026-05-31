{
  config,
  lib,
  specialArgs,
  ...
}: let
  t = lib.types;
  groupType = t.submoduleWith {
    modules = [
      (import ./group.nix {
        inherit (config) overrideAll;
        inherit (config) overrides;
      })
    ];
    inherit specialArgs;
  };
in
  lib.mkOption {
    type = t.lazyAttrsOf groupType;
    description = ''
      Holds multiple package sets (eg. groups).
      Holds shared config (overrideAll) and overrides on a global and on a per group basis.
    '';
  }
