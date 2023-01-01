{framework, ...}: let
  lib = framework.lib;
  t = lib.types;
in {
  options = {
    disabled = lib.mkOption {
      type = t.bool;
      default = false;
    };
    discoverProject = lib.mkOption {
      type = t.nullOr (t.uniq (t.functionTo (t.anything)));
      default = null;
    };
    extraArgs = lib.mkOption {
      default = {};
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
    generateUnitTestsForProjects = lib.mkOption {
      type = t.listOf t.anything;
      default = [];
    };
    name = lib.mkOption {
      type = t.str;
    };
    subsystem = lib.mkOption {
      type = t.str;
    };
    translate = lib.mkOption {
      type = t.nullOr (t.uniq (t.functionTo t.attrs));
      default = null;
    };
    finalTranslate = lib.mkOption {
      type = t.nullOr (t.uniq (t.functionTo t.attrs));
      readOnly = true;
      description = ''
        the final translate that you should use.
      '';
    };
    translateBin = lib.mkOption {
      type = t.nullOr t.package;
      default = null;
    };
    finalTranslateBin = lib.mkOption {
      type = t.nullOr t.package;
      readOnly = true;
      description = ''
        the final translateBin that you should use.
      '';
    };
    type = lib.mkOption {
      type = t.enum [
        "ifd"
        "impure"
        "pure"
      ];
    };
    version = lib.mkOption {
      type = t.int;
      default = 2;
    };
    translatorOptions = lib.mkOption {
      type = t.attrs;
      # TODO: remove the default once the `extraArgs` field of translators is
      #   deprecated.
      default = {};
    };
  };
}
