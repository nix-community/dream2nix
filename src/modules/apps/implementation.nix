{config, ...}: let
  l = config.lib;
  appsDir = "${../../.}/apps";
  appNames = l.attrNames (l.readDir appsDir);
  appModules =
    l.genAttrs
    appNames
    (name: import "${appsDir}/${name}" config);
in {
  config = {
    apps = appModules;
    flakeApps =
      l.mapAttrs (
        appName: app: {
          type = "app";
          program = "${app}/bin/${appName}";
        }
      )
      {
        inherit
          (config.apps)
          contribute
          install
          translate
          runNixCmdInSrc
          index
          translate-index
          ;
      };
  };
}
