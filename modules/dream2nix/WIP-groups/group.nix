{
  overrideAll,
  overrides,
}: {
  config,
  dream2nix,
  lib,
  specialArgs,
  ...
}: let
  t = lib.types;
  packageType = name:
    t.deferredModuleWith {
      staticModules = [
        # the top-level overrideAll
        overrideAll
        # the overrideAll of the current group
        config.overrideAll
        # the global overrides
        (overrides.${name} or {})
        # the overrides of the current group
        (config.overrides.${name} or {})
      ];
    };
in {
  options = {
    overrideAll = lib.mkOption {
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
        Holds overrides for the packages in the current groups
      '';
      default = {};
    };
    packages = lib.mkOption {
      description = ''
        Contains all packages for the current group in the forma of a set like:
        ```
        {
          package1."1.0.0" = {
            module = {
              # the package configuration
            };
            public = {
              # the evaluated package
            };
          };
          package2."1.0.0" = {
            module = {
              # the package configuration
            };
            public = {
              # the evaluated package
            };
          };
        }
        ```
      '';
      #      name           version       options
      type = let
        submoduleWithNameVersion = import ./submoduleWithNameVersion.nix {
          inherit lib;
        };
      in
        t.lazyAttrsOf (t.lazyAttrsOf (submoduleWithNameVersion {
          modules = [
            ({
              config,
              name,
              version,
              ...
            }: {
              options.module = lib.mkOption {
                # this is a deferredModule type
                type = packageType name;
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
    };
  };
}
