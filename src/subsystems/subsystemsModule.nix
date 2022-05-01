{
  pkgs,
  callPackageDream,
  lib,
  dlib,
  config,
  specialArgs,
  ...
}: let
  inherit (lib) mkOption types attrsets debug;

  # toplevelConfig = config;

  # subsystem = "nodejs-test";

  purityType = types.enum ["pure" "impure"];

  discoveredProjectsType = types.anything;

  discoverFunctionType = types.functionTo discoveredProjectsType;

  discovererModule = types.submoduleWith {
    inherit specialArgs;

    shorthandOnlyDefinesConfig = true;
    modules = [
      # TODO: this should come from somewhere
      {_module.args.subsystem = "nodejs";}
      ({
        name,
        config,
        dlib,
        subsystem,
        ...
      }: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
          };

          type = mkOption {
            type = purityType;
            default = "pure";
          };

          subsystem = mkOption {
            type = types.str;
            default = subsystem;
          };

          discover = mkOption {
            type = discoverFunctionType;
          };
        };
      })
    ];
  };

  translatorModule = types.submoduleWith {
    inherit specialArgs;

    shorthandOnlyDefinesConfig = true;
    modules = [
      # TODO: this should come from somewhere
      {_module.args.subsystem = "nodejs";}
      ({
        name,
        config,
        dlib,
        subsystem,
        ...
      }: {
        options = {
          version = mkOption {
            type = types.int;
            default = 1;
          };

          type = mkOption {type = purityType;};

          translate = mkOption {
            type = types.nullOr (types.functionTo (types.anything));
            default = null;
          };

          translateBin = mkOption {
            type = types.nullOr (types.functionTo (types.anything));
            default = null;
          };

          extraArgs = mkOption {
            type = types.attrs;
            default = {};
          };
        };
      })
    ];
  };

  fetcherModule = types.submodule {
    options = {
      type = mkOption {type = purityType;};

      inputs = mkOption {type = types.listOf (types.str);};

      versionField = mkOption {type = types.str;};

      defaultUpdater = mkOption {type = types.str;};

      parseParams = mkOption {type = types.functionTo (types.attrs);};

      outputs = mkOption {type = types.functionTo (types.attrs);};
    };
  };

  builderModule = types.submodule {
    options = {
      type = mkOption {type = purityType;};

      packages = mkOption {
        type = types.attrs;
        default = {};
      };
    };
  };

  # subsystemModule = ({ config, ... }: {
  # subsystemType = types.submodule ({ name, config, ... }: { # (lib.traceValFn (x: "!!name: ${name}") {
  subsystemType = types.submoduleWith {
    inherit specialArgs;

    shorthandOnlyDefinesConfig = true;
    modules = [
      # { _module.args.subsystem = subsystem; }
      ({
        name,
        config,
        ...
      }: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
          };

          discoverers = mkOption {
            type = types.attrsOf discovererModule;
            default = {};
          };

          translators = mkOption {
            type = types.attrsOf translatorModule;
            default = {};
          };

          fetchers = mkOption {
            type = types.attrsOf fetcherModule;
            default = {};
          };

          builders = mkOption {
            type = types.attrsOf builderModule;
            default = {};
          };
        };

        config = {
          _module.args.subsystem = lib.traceVal name; # (lib.traceValFn (x: "!!name: ${x}") name);
        };
      })
    ];
  };
  # subsystemsModule' = (types.attrsOf subsystemModule);
  # subsystemModule = subsystemModule' // {
  # };
  # subsystemsModule = types.submodule ({ config, ... }: {
  #   config = {
  #     _module = {
  #       freeformType = types.attrsOf subsystemType;
  #       # args.subsystem = (lib.traceVal (lib.trace "KEK" config)).name;
  #     };
  #   };
  # });
in {
  options = {
    subsystems = mkOption {
      type = types.attrsOf subsystemType;
      default = {};
    };
    # subsystems  =  mkOption { type = subsystemsModule; default = {}; };

    discoverers = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
    translators = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
    fetchers = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
    updaters = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
    builders = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };

    # TODO: this probably shouldn't be options?
    # applyProjectSettings = mkOption { type = types.anything; };
    # discoverProjects     = mkOption { type = types.anything; } ;
  };

  # config = let
  #   discoverers = let
  #       subsystemToDiscoverers = (subsystem: { discoverers ? {}, ... }:
  #         attrsets.mapAttrs
  #           (name: discoverer: discoverer) # (discoverer) // { inherit name subsystem; })
  #           discoverers);
  #     in
  #       attrsets.mapAttrs subsystemToDiscoverers config.subsystems;

  #   # instantiatedDiscoverers = import ../discoverers { inherit config dlib lib discoverers; };
  # in
  #   {
  #     # inherit (instantiatedDiscoverers) applyProjectSettings discoverProjects discoverers;

  #     inherit discoverers;
  #   };

  config = let
    collectDiscoverers = name: subsystem: subsystem.discoverers;
    discoverers = attrsets.mapAttrs collectDiscoverers config.subsystems;

    kek = callPackageDream ../translators {inherit dlib lib;};

    inherit (kek) makeTranslator;

    collectTranslators = name: subsystem: rec {
      # all = lib.mapAttrs (_: t: makeTranslator t) subsystem.translators;
      pure = lib.mapAttrs (_: t: makeTranslator t) (attrsets.filterAttrs (_: t: t.type == "pure") subsystem.translators);
      impure = lib.mapAttrs (_: t: makeTranslator t) (attrsets.filterAttrs (_: t: t.type == "impure") subsystem.translators);

      all = impure // pure;
    };
    translators = attrsets.mapAttrs collectTranslators config.subsystems;
    # collectTranslators = name: subsystem: rec {
    #   all = lib.traceVal (callPackageDream ../translators { inherit dlib lib; translators = subsystem.translators; }).translators;
    #   pure = {};
    #   impure = {};
    #   # pure = attrsets.filterAttrs (_: t: t.type == "pure") all;
    #   # impure = attrsets.filterAttrs (_: t: t.type == "impure") all;
    # };
    # translators = attrsets.mapAttrs collectTranslators config.subsystems;
    # collectTranslators = name: subsystem: subsystem.translators;
    # translators = attrsets.mapAttrs collectTranslators config.subsystems; # (callPackageDream ../translators { inherit dlib lib; translators = (attrsets.mapAttrs collectTranslators config.subsystems); }).translators;
  in {
    inherit discoverers translators;

    _module.args = {inherit discoverers translators;};
  };
}
