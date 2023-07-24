# Automatically exports modules from the `/**/modules` directory to:
#   `flake.modules.<kind>.<name>`
# Automatically imports all flake-parts modules from `/**/modules/flake-parts`
{
  config,
  lib,
  ...
}: let
  modulesDir = ../.;

  moduleKinds = builtins.readDir modulesDir;

  mapModules = kind:
    lib.mapAttrs'
    (fn: _:
      lib.nameValuePair
      (lib.removeSuffix ".nix" fn)
      (modulesDir + "/${kind}/${fn}"))
    (builtins.readDir (modulesDir + "/${kind}"));

  flakePartsModules = lib.attrValues (
    lib.filterAttrs
    (modName: _: modName != "all-modules")
    (mapModules "flake-parts")
  );
in {
  imports = flakePartsModules;

  options.flake.modules = lib.mkOption {
    type = lib.types.anything;
  };

  # generates future flake outputs: `modules.<kind>.<module-name>`
  config.flake.modules =
    let modules = lib.mapAttrs (kind: _: mapModules kind) moduleKinds;
    in modules // {
      flake-parts = modules.flake-parts // {
        all-modules = { imports = flakePartsModules; _class = "flake-parts"; };
      };
    };

  # comapt to current schema: `nixosModules` / `darwinModules`
  config.flake.nixosModules = config.flake.modules.nixos or {};
  config.flake.darwinModules = config.flake.modules.darwin or {};
}
