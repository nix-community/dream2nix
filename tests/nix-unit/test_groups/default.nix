{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? (import (../../../modules + "/flake.nix")).outputs {},
}: let
  fixtures = import ../fixtures.nix {inherit dream2nix;};
  eval = module:
    (lib.evalModules {
      modules = [
        dream2nix.modules.dream2nix.groups
        module
      ];
      specialArgs = {
        inherit dream2nix;
        packageSets.nixpkgs = pkgs;
      };
    })
    .config;
in {
  test_groups_simple = let
    config = eval {
      groups.my-group.packages.hello."1.0.0" = {...}: fixtures.basic-derivation;
    };
  in {
    expr = config.groups.my-group.public.packages.hello."1.0.0" ? drvPath;
    expected = true;
  };

  test_groups_commonModule = let
    config = eval {
      groups.my-group.packages.hello."1.0.0" = {...}: fixtures.basic-derivation;
      commonModule = {name = lib.mkForce "hello-mod";};
    };
  in {
    expr = "${config.groups.my-group.public.packages.hello."1.0.0".name}";
    expected = "hello-mod";
  };
}
