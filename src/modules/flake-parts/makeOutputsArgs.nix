{lib, ...}: let
  l = lib // builtins;
  t = l.types;
  mkOption = l.options.mkOption;

  project.options = {
    name = mkOption {
      description = "Name of the project";
      type = t.str;
    };

    version = mkOption {
      default = null;
      description = "Version of the project";
      type = t.nullOr t.str;
    };

    relPath = mkOption {
      default = "";
      description = "Relative path to project tree from source";
      type = t.str;
    };

    # TODO(antotocar34) make a smart enum of all available translators conditional on the given the subsystem? Is this possible?
    translator = mkOption {
      description = "Translators to use";
      example = ["yarn-lock" "package-json"];
      type = t.str;
    };

    # TODO(antotocar34) make an enum of all available subsystems?
    subsystem = mkOption {
      description = ''Name of subsystem to use. Examples: rust, python, nodejs'';
      example = "nodejs";
      type = t.str;
    };

    subsystemInfo = mkOption {
      default = {};
      description = "Translator specific arguments";
      type = t.lazyAttrsOf (t.anything);
    };
  };
in {
  options = {
    source = mkOption {
      type = t.either t.path t.package;
      description = "Source of the package to build with dream2nix";
    };

    projects = mkOption {
      default = {};
      type = t.attrsOf (t.submodule project);
      description = "Projects that dream2nix will build";
    };

    pname = mkOption {
      default = null;
      type = t.nullOr t.str;
      description = "The name of the package to be built with dream2nix";
    };

    settings = mkOption {
      default = [];
      type = t.listOf t.attrs;
      example = [
        {
          aggregate = true;
        }
        {
          filter = project: project.translator == "package-json";
          subsystemInfo.npmArgs = "--legacy-peer-deps";
          subsystemInfo.nodejs = 18;
        }
      ];
      description = ''        Settings to customize dream2nix's behaviour.

                This is likely to be removed in the future:
                Quote from DavHau @ https://github.com/nix-community/dream2nix/pull/399/files#r1036801060:
                Eventually this option should be removed.
                This custom settings merging logic I once implemented is an ugly quick hack,
                and not needed anymore since we now have the module system for merging options.
      '';
    };

    packageOverrides = mkOption {
      default = {};
      type = t.lazyAttrsOf t.attrs;
      description = "Overrides to customize build logic for dependencies or top-level packages";
    };

    sourceOverrides = mkOption {
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

    inject = mkOption {
      default = {};
      type = t.lazyAttrsOf (t.listOf (t.listOf t.str));
      description = "Inject missing dependencies into the dependency tree"; # TODO(antotocar34) find a suitable description
      example =
        l.literalExpression
        # TODO(DavHau) don't require specifying the version here. This will break as soon as the dependencies get updated
        ''
          {
            foo."6.4.1" = [
              ["bar" "13.2.0"]
              ["baz" "1.0.0"]
            ];
            "@tiptap/extension-code"."2.0.0-beta.26" = [
              ["@tiptap/core" "2.0.0-beta.174"]
            ];
          };
        '';
    };
  };
}
