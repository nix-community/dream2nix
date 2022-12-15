{config, ...}: let
  l = config.lib;
  t = l.types;
in {
  options = {
    fetchers = l.mkOption {
      type = t.lazyAttrsOf (
        t.submoduleWith {
          modules = [../interfaces.fetcher];
          specialArgs = {framework = config;};
        }
      );
    };
  };
}
