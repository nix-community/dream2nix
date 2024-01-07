{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  imports = [
    ../assertions.nix
    (lib.mkRemovedOptionModule ["lock" "repoRoot"] "Use paths.projectRoot instead.")
    (lib.mkRemovedOptionModule ["lock" "lockFileRel"] "Use paths.package instead.")
  ];
  options.lock = {
    # GLOBAL OPTIONS

    content = l.mkOption {
      type = t.submodule {
        freeformType = t.anything;
      };
      description = ''
        The content of the lock file.
        All fields declared via `lock.fields` are contained pointing to their respective values.
      '';
    };

    extraScripts = l.mkOption {
      type = t.listOf t.path;
      default = "";
      description = ''
        Extra shell scripts to execute when `nix run .#{package}.lock` is called.

        This allows adding custom logic to the lock file generation.
      '';
    };

    fields = l.mkOption {
      type = t.attrsOf (t.submodule [
        {
          options = {
            script = l.mkOption {
              type = t.path;
              description = ''
                A script to refresh the value of this lock file field.
                The script should write the result as json file to $out.
              '';
            };
            default = l.mkOption {
              type = t.nullOr t.anything;
              description = ''
                The default value in case the lock file doesn't exist or doesn't yet contain the field.
              '';
              default = null;
            };
          };
        }
      ]);
      description = "Fields of the lock file";
      default = {};
      example = {
        pname = true;
        version = true;
      };
    };

    invalidationData = l.mkOption {
      type = t.anything;
      description = ''
        Pass any data that should invalidate the lock file when changed.
        This is useful for example when the lock file should be regenerated
        when the requirements change.
      '';
      default = {};
      example = {
        pip.requirements = ["requests" "pillow"];
        pip.lockVersion = "2";
      };
    };

    refresh = l.mkOption {
      type = t.package;
      description = "Script to refresh the cache file of this package";
      readOnly = true;
    };

    lib.computeFODHash = l.mkOption {
      type = t.functionTo t.path;
      description = ''
        Helper function to write the hash of a given FOD to $out.
      '';
      readOnly = true;
    };
  };
}
