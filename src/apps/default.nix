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
    flakeApps =
      b.mapAttrs (
        appName: app: {
          type = "app";
          program = "${app}/bin/${appName}";
        }
      )
      {inherit contribute install translate shell;};

    # the contribute cli
    contribute = callPackageDream ./contribute {};

    # install the framework to a specified location by copying the code
    install = callPackageDream ./install {};

    # translate a given source shortcut
    translate = callPackageDream ./translate {};

    shell = callPackageDream ./shell {};

    fetchSourceShortcut = callPackageDream ./fetchSourceShortcut {};

    callNixWithD2N = callPackageDream ./callNixWithD2N {};
  };
in
  apps
