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

    runNixCmdInSrc = callPackageDream ./runNixCmdInSrc {};

    # index packages with an indexer
    index = callPackageDream ./index {};

    translate-index = callPackageDream ./translate-index {};

    translateSourceShortcut = callPackageDream ./translateSourceShortcut {};

    callNixWithD2N = callPackageDream ./callNixWithD2N {};

    writeFlakeD2N = callPackageDream ./writeFlakeD2N {};

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
          runNixCmdInSrc
          index
          translate-index
          ;
      };
  };
in
  apps
