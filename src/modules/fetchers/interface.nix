{config, ...}: let
  l = config.lib // builtins;
  t = l.types;
in {
  options = {
    fetchers = l.mkOption {
      type = t.attrsOf (
        t.submoduleWith {
          modules = [../interfaces.fetcher];
          specialArgs = {framework = config;};
        }
      );
    };
  };
}
