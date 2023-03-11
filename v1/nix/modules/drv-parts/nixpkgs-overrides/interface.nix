{config, lib, ...}: let
  l = lib // builtins;
  t = l.types;

in {
  options.nixpkgs-overrides = {
    enable = l.mkEnableOption "Whether to apply override from nixpkgs";
  };
}
