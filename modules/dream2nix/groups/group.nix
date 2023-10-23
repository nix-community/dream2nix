{commonModule}: {
  lib,
  dream2nix,
  config,
  specialArgs,
  ...
}: let
  t = lib.types;
  packageType = t.deferredModuleWith {
    staticModules = [
      dream2nix.modules.dream2nix.core
      {_module.args = specialArgs;}
      # the top-level commonModule
      commonModule
      # the commonModule of the current group
      config.commonModule
    ];
  };
in {
  options = {
    commonModule = lib.mkOption {
      type = t.deferredModule;
      description = ''
        Common configuration for all packages in all groups
      '';
      default = {};
    };
    overrides = lib.mkOption {
      type = t.attrs;
      description = ''
        A set of package overrides
      '';
    };
    packages = lib.mkOption {
      #      name           version       options
      type = t.lazyAttrsOf (t.lazyAttrsOf (t.submoduleWith {
        modules = [
          ({config, ...}: {
            options.module = lib.mkOption {
              # this is a deferredModule type
              type = packageType;
              description = ''
                The package configuration
              '';
              default = {};
            };
            options.evaluated = lib.mkOption {
              type = t.submoduleWith {
                modules = [config.module];
                inherit specialArgs;
              };
              description = ''
                The evaluated dream2nix package modules
              '';
              internal = true;
              default = {};
            };
            options.public = lib.mkOption {
              type = t.package;
              description = ''
                The evaluated package ready to consume
              '';
              readOnly = true;
              default = config.evaluated.public;
              defaultText = lib.literalExpression "config.evaluated.public";
            };
          })
        ];
        inherit specialArgs;
      }));
      description = ''
        The packages for this group
      '';
    };
  };
}
