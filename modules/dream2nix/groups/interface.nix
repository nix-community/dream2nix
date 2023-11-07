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
        Holds shared config (overrideAll) and overrides on a global and on a per group basis.
      '';
    };
    overrideAll = lib.mkOption {
      type = t.deferredModule;
      description = ''
        Common overrides for all packages.
        Gets applied on all groups.
      '';
      default = {};
      example = {
        mkDerivation.doCheck = false;
      };
    };
    overrides = lib.mkOption {
      type = t.lazyAttrsOf (t.deferredModuleWith {
        staticModules = [
          {_module.args = specialArgs;}
        ];
      });
      description = ''
        Overrides for specific package names.
        Gets applied on all groups.
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
