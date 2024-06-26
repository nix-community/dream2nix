{
  lib,
  config,
  ...
}: let
  t = lib.types;
in {
  options = {
    editables = lib.mkOption {
      type = t.attrsOf t.str;
    };

    editablesShellHook = lib.mkOption {
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
