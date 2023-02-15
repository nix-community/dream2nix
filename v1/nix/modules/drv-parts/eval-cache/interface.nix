{config, lib, ...}: let
  l = lib // builtins;
  t = l.types;

in {
  options.eval-cache = {

    content = l.mkOption {
      type = t.submodule {
        freeformType = t.anything;
      };
    };

    invalidationFields = l.mkOption {
      type = t.attrsOf t.bool;
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

    fileRel = l.mkOption {
      type = t.path;
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

    fields = l.mkOption {
      type = t.attrsOf t.bool;
      description = "Fields for which to cache evaluation";
      default = {};
      example = {
        pname = true;
        version = true;
      };
    };

    # cache.Module = l.mkOption {
    #   type = t.deferredModule;
    #   default = {config, ...}: {};
    # };

    # load = l.mkOption {
    #   type = t.functionTo t.anything;
    #   description = "Function to convert a cache file to a module that can be imported";
    #   readOnly = true;
    # };
  };
}
