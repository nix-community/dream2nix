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
    };
    npmArgs = {
      type = t.listOf t.str;
      description = "extra arguments to pass to 'npm install'";
      default = [];
    };
  };
}
