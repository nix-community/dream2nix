{
  lib,
  specialArgs,
  ...
}: let
  t = lib.types;
in {
  options = {
    builders = lib.mkOption {
      type = t.attrsOf (t.submoduleWith {
        modules = [./builder/default.nix];
        inherit specialArgs;
      });
      description = ''
        builder module definitions
      '';
    };
    builderInstances = lib.mkOption {
      type = t.attrsOf t.anything;
    };
    buildersBySubsystem = lib.mkOption {
      type = t.attrsOf (t.attrsOf t.anything);
    };
  };
}
