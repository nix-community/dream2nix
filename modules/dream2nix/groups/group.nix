{commonModule}: {
  lib,
  dream2nix,
  config,
  ...
}: let
  t = lib.types;
  packageType = t.deferredModuleWith {
    staticModules = [
      dream2nix.modules.dream2nix.core
      commonModule
    ];
  };
in {
  options = {
    overrides = lib.mkOption {
      type = lib.attrs;
      description = ''
        A set of package overrides
      '';
    };
    packages = lib.mkOption {
      type = t.lazyAttrsOf packageType;
      description = ''
        The package configurations to evaluate
      '';
    };
    packagesEval = lib.mkOption {
      type = t.lazyAttrsOf (t.submoduleWith {modules = [];});
      description = ''
        The evaluated dream2nix package modules
      '';
      internal = true;
    };
    public = lib.mkOption {
      type = t.lazyAttrsOf t.package;
      description = ''
        The evaluated packages ready to consume
      '';
      readOnly = true;
    };
  };
  config = {
    packagesEval = config.packages;
    public = lib.mapAttrs (name: pkg: pkg.public) config.packagesEval;
  };
}
