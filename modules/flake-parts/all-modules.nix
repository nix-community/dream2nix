# Automatically exports modules from the `/**/modules` directory to:
#   `flake.modules.<kind>.<name>`
# Automatically imports all flake-parts modules from `/**/modules/flake-parts`
{
  config,
  lib,
  ...
}: let
  inherit
    (builtins)
    attrValues
    mapAttrs
    readDir
    ;

  # inherit all lib functions used below
  inherit
    (lib)
    mapAttrs'
    filterAttrs
    nameValuePair
    removeSuffix
    mkOption
    types
    ;

  modulesDir = ../.;

  moduleKinds =
    filterAttrs (_: type: type == "directory") (readDir modulesDir);

  mapModules = kind:
    mapAttrs'
    (fn: _:
      nameValuePair
      (removeSuffix ".nix" fn)
      (modulesDir + "/${kind}/${fn}"))
    (readDir (modulesDir + "/${kind}"));

  flakePartsModules = attrValues (
    filterAttrs
    (modName: _: modName != "all-modules")
    (mapModules "flake-parts")
  );
in {
  imports = flakePartsModules;

  options.flake.modules = mkOption {
    type = types.lazyAttrsOf (types.lazyAttrsOf types.raw);
  };

  # generates future flake outputs: `modules.<kind>.<module-name>`
  config.flake.modules = mapAttrs (kind: _: mapModules kind) moduleKinds;

  # comapt to current schema: `nixosModules` / `darwinModules`
  config.flake.nixosModules = config.flake.modules.nixos or {};
  config.flake.darwinModules = config.flake.modules.darwin or {};
}
