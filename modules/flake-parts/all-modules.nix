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
    filterAttrs
    hasSuffix
    mapAttrs'
    mkOption
    nameValuePair
    removeSuffix
    types
    ;

  modulesDir = ../.;

  moduleKinds =
    filterAttrs (_: type: type == "directory") (readDir modulesDir);

  isModule = fname: type:
    (fname != "default.nix")
    && (fname != "test")
    && (fname != "tests")
    && (fname != "_template")
    && (
      (type == "regular" && hasSuffix ".nix" fname) || type == "directory"
    );

  mapModules = kind:
    mapAttrs'
    (fn: _:
      nameValuePair
      (removeSuffix ".nix" fn)
      (modulesDir + "/${kind}/${fn}"))
    (filterAttrs isModule (readDir (modulesDir + "/${kind}")));

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
  config = {
    flake = {
      modules = mapAttrs (kind: _: mapModules kind) moduleKinds;

      # comapt to current schema: `nixosModules` / `darwinModules`
      nixosModules = config.flake.modules.nixos or {};
      darwinModules = config.flake.modules.darwin or {};
    };
  };
}
