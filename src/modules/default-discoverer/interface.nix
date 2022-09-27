{
  lib,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    defaultDiscoverer = l.mkOption {
      type = t.submoduleWith {
        modules = [../discoverers/discoverer];
        inherit specialArgs;
      };
    };
  };
}
