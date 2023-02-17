{config, lib, ...}: let
  l = lib // builtins;
  t = l.types;

in {
  options.eval-cache = {

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

    repoRoot = l.mkOption {
      type = t.path;
      description = "The root of the own repo. Eg. 'self' in a flake";
      example = lib.literalExample ''
        self + /eval-cache.json
      '';
    };

    cacheFileRel = l.mkOption {
      type = t.str;
      description = "Location of the cache file";
      example = lib.literalExample ''
        /rel/path/to/my/package/cache.json
      '';
    };

    newFile = l.mkOption {
      type = t.path;
      description = "Cache file generated from the current inputs";
      internal = true;
      readOnly = true;
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
  };
}
