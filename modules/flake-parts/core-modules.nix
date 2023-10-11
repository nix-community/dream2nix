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
    filterAttrs
    mapAttrs'
    nameValuePair
    removeSuffix
    ;

  path = self + "/modules/dream2nix/core";

  dirs = filterAttrs (name: _: name != "default.nix") (readDir path);

  modules =
    mapAttrs'
    (fn: _:
      nameValuePair
      (removeSuffix ".nix" fn)
      (path + "/${fn}"))
    (filterAttrs (_: type: type == "regular" || type == "directory") dirs);
in {
  # generates future flake outputs: `modules.<kind>.<module-name>`
  config.flake.modules.dream2nix = modules;
}
