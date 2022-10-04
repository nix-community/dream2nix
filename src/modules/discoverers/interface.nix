{
  lib,
  specialArgs,
  ...
}: let
  t = lib.types;
in {
  options = {
    discoverers = lib.mkOption {
      type = t.attrsOf (t.submoduleWith {
        modules = [../interfaces.discoverer];
        inherit specialArgs;
      });
      description = ''
        discoverer module definitions
      '';
    };
    discoverersBySubsystem = lib.mkOption {
      type = t.attrsOf (t.attrsOf t.anything);
    };
  };
}
