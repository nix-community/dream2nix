{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.lock = {
    # GLOBAL OPTIONS
    repoRoot = l.mkOption {
      type = t.path;
      description = "The root of the current repo. Eg. 'self' in a flake";
      example = lib.literalExpression ''
        self
      '';
    };

    lockFileRel = l.mkOption {
      type = t.str;
      description = "Location of the cache file relative to the repoRoot";
      example = lib.literalExpression ''
        /rel/path/to/my/package/cache.json
      '';
    };

    content = l.mkOption {
      type = t.submodule {
        freeformType = t.anything;
      };
    };

    fields = l.mkOption {
      type = t.attrs;
      description = "Fields to manage via a lock file";
      default = {};
      example = {
        pname = true;
        version = true;
      };
    };

    refresh = l.mkOption {
      type = t.package;
      description = "Script to refresh the cache file of this package";
      readOnly = true;
    };
  };
}
