{
  lib,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    fetchers = l.mkOption {
      type = t.attrsOf (
        t.submoduleWith {
          modules = [../interfaces.fetcher];
          inherit specialArgs;
        }
      );
    };
  };
}
