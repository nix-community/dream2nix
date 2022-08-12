{
  config,
  lib,
  ...
}: let
  t = lib.types;
in {
  options = {
    name = lib.mkOption {
      type = t.str;
    };
    subsystem = lib.mkOption {
      type = t.str;
    };
    disabled = lib.mkOption {
      type = t.bool;
      default = false;
    };
    version = lib.mkOption {
      type = t.int;
      default = 2;
    };
    discoverProject = lib.mkOption {
      type = t.nullOr (t.functionTo (t.anything));
      default = null;
    };
    generateUnitTestsForProjects = lib.mkOption {
      type = t.listOf t.anything;
      default = [];
    };
    type = lib.mkOption {
      type = t.enum [
        "ifd"
        "impure"
        "pure"
      ];
    };
    translate = lib.mkOption {
      type = t.nullOr (t.functionTo (t.functionTo (t.attrs)));
      default = null;
    };
    translateBin = lib.mkOption {
      type = t.nullOr (t.functionTo t.package);
      default = null;
    };
    extraArgs = lib.mkOption {
      type = t.attrsOf (t.submodule {
        options = {
          description = lib.mkOption {
            type = t.str;
          };
          default = lib.mkOption {
            type = t.nullOr t.anything;
            default = null;
          };
          examples = lib.mkOption {
            type = t.listOf t.str;
            default = [];
          };
          type = lib.mkOption {
            type = t.enum ["argument" "flag"];
          };
        };
      });
    };
  };
}
