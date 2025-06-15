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
    hasSuffix
    mapAttrs'
    nameValuePair
    removeSuffix
    ;

  path = ../dream2nix/core;

  isModule = fname: type:
    (fname != "default.nix")
    && (fname != "test")
    && (fname != "tests")
    && (fname != "_template")
    && (
      (type == "regular" && hasSuffix ".nix" fname) || type == "directory"
    );

  modules =
    mapAttrs'
    (fn: _:
      nameValuePair
      (removeSuffix ".nix" fn)
      (path + "/${fn}"))
    (filterAttrs isModule (readDir path));
in {
  # generates future flake outputs: `modules.<kind>.<module-name>`
  config.flake.modules.dream2nix = modules;
}
