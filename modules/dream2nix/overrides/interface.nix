{
  lib,
  specialArgs,
  config,
  ...
}: let
  t = lib.types;
  staticModules = [
    {_module.args = specialArgs;}
    config.overrideType
  ];
in {
  options = {
    overrideAll = lib.mkOption {
      type = t.deferredModuleWith {inherit staticModules;};
      description = ''
        Overrides applied on all dependencies.
      '';
      default = {};
      example = {
        mkDerivation.doCheck = false;
      };
    };

    overrides = lib.mkOption {
      type = t.attrsOf (t.deferredModuleWith {inherit staticModules;});
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
      type = t.deferredModule;
      default = {};
      internal = true;
    };
  };
}
