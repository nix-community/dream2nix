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
        inherit (config) commonModule;
        globalOverrides = config.overrides;
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
        Holds shared config (commonModule) and overrides on a global and on a per group basis.
      '';
    };
    commonModule = lib.mkOption {
      type = t.deferredModule;
      description = ''
        Common configuration for all packages in all groups
      '';
      default = {};
    };
    overrides = lib.mkOption {
      type = t.lazyAttrsOf (t.deferredModuleWith {
        staticModules = [
          {_module.args = specialArgs;}
        ];
      });
      description = ''
        Holds overrides for all packages in all groups
      '';
      default = {};
      example = {
        hello.postPatch = ''
          substituteInPlace Makefile --replace /usr/local /usr
        '';
      };
    };
  };
}
