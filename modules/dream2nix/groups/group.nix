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
      commonModule
      {_module.args = specialArgs;}
    ];
  };
in {
  options = {
    overrides = lib.mkOption {
      type = t.attrs;
      description = ''
        A set of package overrides
      '';
    };
    packages = lib.mkOption {
      type = t.lazyAttrsOf (t.lazyAttrsOf packageType);
      description = ''
        The package configurations to evaluate
      '';
    };
    packagesEval = lib.mkOption {
      type = t.lazyAttrsOf (t.lazyAttrsOf (t.submoduleWith {modules = [];}));
      description = ''
        The evaluated dream2nix package modules
      '';
      internal = true;
    };
    public.packages = lib.mkOption {
      type = t.lazyAttrsOf (t.lazyAttrsOf t.package);
      description = ''
        The evaluated packages ready to consume
      '';
      readOnly = true;
    };
  };
  config = {
    packagesEval = config.packages;
    public.packages =
      lib.mapAttrs
      (name: versions: lib.mapAttrs (version: pkg: pkg.public) versions)
      config.packagesEval;
  };
}
