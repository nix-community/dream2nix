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
      (import ./group.nix {inherit (config) commonModule;})
    ];
    inherit specialArgs;
  };
in {
  options = {
    groups = lib.mkOption {
      type = t.lazyAttrsOf groupType;
      description = ''
        A set of packages
      '';
    };
    commonModule = lib.mkOption {
      type = t.deferredModule;
      description = ''
        Common configuration for all packages in all groups
      '';
      default = {};
    };
  };
}
