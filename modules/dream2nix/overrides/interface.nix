{
  lib,
  specialArgs,
  config,
  ...
}: let
  t = lib.types;

  # Monkey patch deferredModuleWith to accept specialArgs
  # TODO: upstream specialArgs to deferredModuleWith in nixpkgs
  deferredModuleWith = attrs @ {
    staticModules ? [],
    specialArgs ? {},
  }:
    t.deferredModuleWith {inherit staticModules;}
    // {
      inherit
        (t.submoduleWith {
          modules = staticModules;
          inherit specialArgs;
        })
        getSubOptions
        getSubModules
        ;
      substSubModules = m:
        deferredModuleWith (attrs
          // {
            staticModules = m;
          });
    };
in {
  options = {
    overrideAll = lib.mkOption {
      type = deferredModuleWith {
        inherit specialArgs;
        staticModules = [config.overrideType];
      };
      description = ''
        Overrides applied on all dependencies.
      '';
      default = {};
      example = {
        mkDerivation.doCheck = false;
      };
    };

    overrides = lib.mkOption {
      type = t.attrsOf (deferredModuleWith {
        inherit specialArgs;
        staticModules = [config.overrideType];
      });
      description = ''
        Overrides applied only on dependencies matching the specified name.
      '';
      default = {};
      example = {
        hello.mkDerivation.postPatch = ''
          substituteInPlace Makefile --replace /usr/local /usr
        '';
      };
    };

    ## INTERNAL
    overrideType = lib.mkOption {
      type = deferredModuleWith {
        inherit specialArgs;
      };
      default = {};
      internal = true;
    };
  };
}
