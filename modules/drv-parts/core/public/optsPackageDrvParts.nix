# Adds drv-parts specific fields to the final derivation.
{lib, ...}: let
  l = lib // builtins;
  t = l.types;
in {
  config = l.mkOption {
    type = t.raw;
    readOnly = true;
    description = "The config of the evaluated modules which created the package";
  };
  extendModules = l.mkOption {
    type = t.raw;
    description = "Allows to modify the existing package by extending it with more modules";
  };

  # TODO: implement override functions for downward compatibility
  # overrideAttrs = l.mkOption {
  #   type = t.path;
  #   description = "Legacy machanism for modifying the package. Use `extendModules` instead";
  # };
  # override = l.mkOption {
  #   type = t.str;
  #   description = "Legacy machanism for modifying the package. Use `extendModules` instead";
  # };
}
