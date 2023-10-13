{
  lib,
  config,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.spago = {
    spagoYamlFile = l.mkOption {
      type = t.path;
      default = "${config.mkDerivation.src}/spago.yaml";
    };

    sources = l.mkOption {
      type = t.lazyAttrsOf t.package;
    };
  };
}
