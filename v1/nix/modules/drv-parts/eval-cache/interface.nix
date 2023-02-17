{config, lib, ...}: let
  l = lib // builtins;
  t = l.types;

in {
  options.eval-cache = {

    # GLOBAL OPTIONS
    repoRoot = l.mkOption {
      type = t.path;
      description = "The root of the current repo. Eg. 'self' in a flake";
      example = lib.literalExample ''
        self
      '';
    };

    cacheFileRel = l.mkOption {
      type = t.str;
      description = "Location of the cache file relative to the repoRoot";
      example = lib.literalExample ''
        /rel/path/to/my/package/cache.json
      '';
    };

    # LOCAL OPTIONS
    enable = l.mkEnableOption {
      description =
        "Whether to enable the evaluation cache for this derivation";
    };

    content = l.mkOption {
      type = t.submodule {
        freeformType = t.anything;
      };
    };

    invalidationFields = l.mkOption rec {
      type = t.attrsOf (t.oneOf [t.bool type]);
      description = "Fields, when changed, require refreshing the cache";
      default = {};
      example = {
        src = true;
      };
    };

    fields = l.mkOption rec {
      type = t.attrsOf (t.oneOf [t.bool type]);
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
  };
}
