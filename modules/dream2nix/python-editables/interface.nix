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
        An attribute set mapping package names to a path, absolute or relative,
        of source directories which should be installed in editable mode in
        [editablesShellHook](#pipeditablesshellhook).
        i.e.

        ```
          pip.editables.charset-normalizer = "/home/user/src/charset-normalizer".
        ```

        The top-level package is included automatically.

        This must be a string, as otherwise content would be copied to the nix store
        and loaded from there, voiding the benefits of editable installs.
        For the same reason, it is advised to use source filtering if you
        use a path inside the current repo to avoid unecessary rebuilds.
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
