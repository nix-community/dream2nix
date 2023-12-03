{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  imports = [
    ../nodejs-package-lock/interface.nix
  ];
  options.nodejs-package-json = l.mapAttrs (_: l.mkOption) {
    source = {
      type = t.either t.path t.package;
      description = "Source of the package";
      default = config.mkDerivation.src;
      defaultText = "config.mkDerivation.src";
    };
    npmArgs = {
      type = t.listOf t.str;
      description = "extra arguments to pass to 'npm install'";
      default = [];
    };
  };
  options.deps = l.mapAttrs (_: l.mkOption) {
    npm = {
      type = t.package;
      description = "The npm package used to build the lock file";
    };
  };
}
