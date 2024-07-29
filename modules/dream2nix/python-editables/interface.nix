{
  lib,
  config,
  ...
}: let
  t = lib.types;
in {
  options = {
    editables = lib.mkOption {
      description = ''
        An attribute set mapping package names to absolute paths of source directories
        which should be installed in editable mode in [editablesShellHook](#pipeditablesshellhook).
        i.e.

        ```
          pip.editables.charset-normalizer = "/home/user/src/charset-normalizer".
        ```

        The top-level package is added automatically.
      '';
      type = t.attrsOf t.str;
    };

    editablesShellHook = lib.mkOption {
      description = ''
        A shellHook to be included into your devShells to install [editables](#pipeditables)
      '';
      type = t.str;
      readOnly = true;
    };

    editablesDevShell = lib.mkOption {
      type = t.package;
      readOnly = true;
    };

    name = lib.mkOption {
      type = t.str;
      internal = true;
    };

    paths = lib.mkOption {
      type = t.attrsOf t.str;
      default = {};
      internal = true;
    };

    pyEnv = lib.mkOption {
      type = t.package;
      internal = true;
    };
  };
}
