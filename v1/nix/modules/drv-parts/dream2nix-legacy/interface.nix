{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.dream2nix-legacy = {
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
    source = l.mkOption {
      type = t.either t.path t.package;
      description = "Source of the package to build with dream2nix";
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

    # overrides
    packageOverrides = l.mkOption {
      default = {};
      type = t.lazyAttrsOf t.attrs;
      description = "Overrides to customize build logic for dependencies or top-level packages";
    };
    sourceOverrides = l.mkOption {
      default = old: {};
      type = t.functionTo (t.lazyAttrsOf (t.listOf t.package));
      description = ''
        Override the sources of dependencies or top-level packages.
        For more details, refer to
        https://nix-community.github.io/dream2nix/intro/override-system.html
      '';
      example = l.literalExpression ''
        oldSources: {
        bar."13.2.0" = builtins.fetchTarball {
          url = "https://example.com/example.tar.gz";
          sha256 = "sha256-0000000000000000000000000000000000000000000=";
        };
        baz."1.0.0" = builtins.fetchTarball {
          url = "https://example2.com/example2.tar.gz";
          sha256 = "sha256-0000000000000000000000000000000000000000000=";
        };
      '';
    };
  };
}
