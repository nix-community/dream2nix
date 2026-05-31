{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  inputs ? {},
  dream2nix ? import ../../.. inputs,
}: let
  fixtures = import ../fixtures.nix {inherit dream2nix;};
  eval = module:
    (lib.evalModules {
      modules = [
        module
        dream2nix.modules.dream2nix.multi-derivation-package
      ];
      specialArgs = {
        inherit dream2nix;
        packageSets.nixpkgs = pkgs;
      };
    })
    .config;
  config = eval (
    {
      config,
      specialArgs,
      ...
    }: let
      dreamTypes = import ../../../lib/types {
        inherit dream2nix lib specialArgs;
      };
    in {
      options.dist = lib.mkOption {
        type = dreamTypes.drvPart;
        description = "The derivation module describing the dist output";
      };
      config = {
        public.dist = config.dist.public;
        out = _: fixtures.named-derivation "hello-out";
        dist = _: fixtures.named-derivation "hello-dist";
      };
    }
  );
in {
  test_toplevel_drvPath_exists = {
    expr = config ? drvPath;
    expected = true;
  };

  test_out_drvPath_exists = {
    expr = config.out ? drvPath;
    expected = true;
  };

  test_dist_drvPath_exists = {
    expr = config.dist ? drvPath;
    expected = true;
  };

  test_toplevel_equals_out = {
    expr =
      config.drvPath
      == config.out.drvPath;
    expected = true;
  };

  test_toplevel_not_has_attr_builder = {
    expr = config ? builder;
    expected = false;
  };

  test_out_not_has_attr_builder = {
    expr = config.out ? builder;
    expected = false;
  };

  test_toplevel_name = {
    expr = config.name;
    expected = "hello-out";
  };

  test_out_name = {
    expr = config.out.name;
    expected = "hello-out";
  };

  test_dist_name = {
    expr = config.dist.name;
    expected = "hello-dist";
  };
}
