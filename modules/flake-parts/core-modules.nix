# Automatically exports modules from the `/**/modules` directory to:
#   `flake.modules.<kind>.<name>`
# Automatically imports all flake-parts modules from `/**/modules/flake-parts`
{
  config,
  lib,
  self,
  ...
}: let
  # inherit all lib functions used below
  inherit
    (builtins)
    readDir
    ;
  inherit
    (lib)
    mapAttrs'
    filterAttrs
    nameValuePair
    removeSuffix
    ;

  mapModules = path:
    mapAttrs'
    (fn: _:
      nameValuePair
      (removeSuffix ".nix" fn)
      (path + "/${fn}"))
    (filterAttrs (_: type: type == "regular" || type == "directory") (readDir path));
in {
  # generates future flake outputs: `modules.<kind>.<module-name>`
  config.flake.modules.dream2nix = mapModules (self + "/modules/dream2nix/core");
}
