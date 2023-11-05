{self, ...}: let
  overridesDir = ../../overrides;
in {
  flake.overrides =
    builtins.mapAttrs
    (
      category: _type:
        builtins.mapAttrs
        (name: _type: overridesDir + "/${category}/${name}")
        (builtins.readDir (overridesDir + "/${category}"))
    )
    (builtins.readDir overridesDir);
}
