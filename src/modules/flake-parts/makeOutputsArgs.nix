{lib, ...}: let
  l = lib // builtins;
  t = l.types;
  mkOption = l.options.mkOption;

  project.options = {
    name = mkOption {
      description = "name of the project";
      type = t.str;
    };

    # TODO(antotocar34) Is the type correct here?
    relPath = mkOption {
      default = "";
      description = "relative path to project tree from source";
      type = t.str;
    };

    # TODO(antotocar34) make a smart enum of all available translators conditional on the given the subsystem? Is this possible?
    translator = mkOption {
      description = "translators to use";
      example = ["yarn-lock" "package-json"];
      type = t.str;
    };

    # TODO(antotocar34) make an enum of all available subsystems?
    subsystem = mkOption {
      description = ''name of subsystem to use. Examples: rust, python, nodejs'';
      example = "nodejs";
      type = t.str;
    };

    subsystemInfo = mkOption {
      default = {}; # TODO(antotocar34) Does there need to be a default?
      description = ""; # TODO(antotocar34) what exactly is this?
      # example = "";
      type = t.lazyAttrsOf (t.anything);
    };
  };
in {
  options = {
    source = mkOption {
      type = t.either t.path t.package;
      description = "source of the package to build with dream2nix";
    };

    projects = mkOption {
      default = {};
      type = t.attrsOf (t.submodule project);
      description = "projects that dream2nix will build";
    };

    discoveredProjects = mkOption {
      # Let default be null so we can pass a default argument to makeOutputs
      default = [];
      internal = true; # TODO should this option be exposed to the user?
      # TODO should it be readonly?
      type = t.nullOr (t.listOf (t.submodule project));
      description = "the projects found by the discoverer";
    };

    pname = mkOption {
      default = null;
      type = t.nullOr t.str;
      description = "package name";
    };

    settings = mkOption {
      default = [];
      # TODO(antotocar34) Refine type
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
      description = "settings to customize dream2nix's behaviour";
    };

    packageOverrides = mkOption {
      default = {};
      type = t.lazyAttrsOf t.attrs;
      # TODO(antotocar34) is this the right description
      description = "Overrides to customize build logic for certain dependencies";
    };

    sourceOverrides = mkOption {
      default = old: {};
      type = t.functionTo (t.lazyAttrsOf (t.listOf t.package));
      description = ""; # TODO(antotocar34) find a suitable description
      example = oldSources: {
        bar."13.2.0" = builtins.fetchTarball {
          url = "https://example.com/example.tar.gz";
          sha256 = "";
        };
        baz."1.0.0" = builtins.fetchTarball {
          url = "https://example2.com/example2.tar.gz";
          sha256 = "";
        };
      };
    };

    inject = mkOption {
      default = {};
      type = t.lazyAttrsOf (t.listOf (t.listOf t.str));
      description = ""; # TODO(antotocar34) find a suitable description
      example = {
        foo."6.4.1" = [
          ["bar" "13.2.0"]
          ["baz" "1.0.0"]
        ];
        "@tiptap/extension-code"."2.0.0-beta.26" = [
          ["@tiptap/core" "2.0.0-beta.174"]
        ];
      };
    };
  };
}
