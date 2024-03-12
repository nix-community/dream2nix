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
      internal = true;
      description = ''
        The content of the cached fields.
        For example if fields.pname is set to true, then content.pname will exist.
      '';
    };

    invalidationFields = l.mkOption {
      type = t.attrsOf t.anything;
      internal = true;
      description = "Fields, when changed, require refreshing the cache";
      default = {};
      example = {
        src = true;
      };
    };

    fields = l.mkOption {
      type = t.attrsOf t.anything;
      internal = true;
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
      internal = true;
      description = "Script to refresh the eval cache file";
      readOnly = true;
    };
  };
}
