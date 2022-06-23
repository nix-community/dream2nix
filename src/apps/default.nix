{
  callPackageDream,
  dream2nixWithExternals,
  config,
  ...
} @ topArgs: let
  b = builtins;

  callPackageDream = f: args:
    topArgs.callPackageDream f (args // (b.removeAttrs apps ["flakeApps"]));

  apps = rec {
    # the contribute cli
    contribute = callPackageDream ./contribute {};

    # install the framework to a specified location by copying the code
    install = callPackageDream ./install {};

    # translate a given source shortcut
    translate = callPackageDream ./translate {};

    # enter a shell with the packages from a specified source
    shell = callPackageDream ./shell {};

    # index packages with an indexer
    index = callPackageDream ./index {};

    fetchSourceShortcut = callPackageDream ./fetchSourceShortcut {};

    callNixWithD2N = callPackageDream ./callNixWithD2N {};

    flakeApps =
      b.mapAttrs (
        appName: app: {
          type = "app";
          program = "${app}/bin/${appName}";
        }
      )
      {
        inherit
          contribute
          install
          translate
          shell
          index
          ;
      };
  };
in
  apps
