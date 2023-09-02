{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.eval-cache = {
    # LOCAL OPTIONS
    enable = l.mkEnableOption "the evaluation cache for this derivation";

    content = l.mkOption {
      type = t.submodule {
        freeformType = t.anything;
      };
    };

    invalidationFields = l.mkOption {
      type = t.attrsOf t.anything;
      description = "Fields, when changed, require refreshing the cache";
      default = {};
      example = {
        src = true;
      };
    };

    fields = l.mkOption {
      type = t.attrsOf t.anything;
      description = "Fields for which to cache evaluation";
      default = {};
      example = {
        pname = true;
        version = true;
      };
    };

    # INTERNAL OPTIONS
    newFile = l.mkOption {
      type = t.path;
      description = "Cache file generated from the current inputs";
      internal = true;
      readOnly = true;
    };

    refresh = l.mkOption {
      type = t.path;
      description = "Script to refresh the cache file of this package";
      readOnly = true;
    };
  };
}
