{
  config,
  options,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
  cfg = config.php-composer-lock;
in {
  options.php-composer-lock = l.mapAttrs (_: l.mkOption) {
    dreamLock = {
      type = t.attrs;
      internal = true;
      description = "The content of the dream2nix generated lock file";
    };
    composerJsonFile = {
      type = t.path;
      description = ''
        The composer.json file to use.
      '';
      default = cfg.source + "/composer.json";
    };
    composerJson = {
      type = t.attrs;
      description = "The content of the composer.json";
    };
    composerLockFile = {
      type = t.nullOr t.path;
      description = ''
        The composer.lock file to use.
      '';
      default = cfg.source + "/composer.lock";
    };
    composerLock = {
      type = t.attrs;
      description = "The content of the composer.lock";
    };
    source = {
      type = t.either t.path t.package;
      description = "Source of the package";
      default = config.mkDerivation.src;
    };
    withDevDependencies = {
      type = t.bool;
      default = true;
      description = ''
        Whether to include development dependencies.
        Usually it's a bad idea to disable this, as development dependencies can contain important build time dependencies.
      '';
    };
  };
}
