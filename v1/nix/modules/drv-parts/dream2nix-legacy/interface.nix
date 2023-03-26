{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.legacy = {
    builder = l.mkOption {
      description = "Builder to use";
      example = ["build-rust-package"];
      type = t.str;
    };
    relPath = l.mkOption {
      default = "";
      description = "Relative path to project tree from source";
      type = t.str;
    };
    subsystem = l.mkOption {
      description = ''Name of subsystem to use. Examples: rust, python, nodejs'';
      example = "nodejs";
      type = t.str;
    };
    subsystemInfo = l.mkOption {
      default = {};
      description = "Translator specific arguments";
      type = t.lazyAttrsOf (t.anything);
    };
    translator = l.mkOption {
      description = "Translator to use";
      example = ["yarn-lock" "package-json"];
      type = t.str;
    };
  };
}
