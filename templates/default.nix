{
  lib,
  self,
  ...
}: let
  l = lib // builtins;
in {
  flake = {
    v1-python = {
      description = "Simple dream2nix python project";
      path = ./v1-python;
    };
  };
}
