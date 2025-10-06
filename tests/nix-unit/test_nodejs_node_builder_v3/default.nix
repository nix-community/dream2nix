{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  inputs ? {},
  dream2nix ? import ../../.. inputs,
}: let
  eval = module:
    lib.evalModules {
      modules = [module];
      specialArgs = {
        inherit dream2nix;
        packageSets = {
          nixpkgs = pkgs;
        };
      };
    };
in {
  test_nodejs_eval_dist = let
    evaled = eval ({config, ...}: {
      imports = [
        dream2nix.modules.dream2nix.WIP-nodejs-builder-v3
      ];
      WIP-nodejs-builder-v3.packageLockFile = ./package-lock.json;
    });
    inherit (evaled) config;
  in {
    expr = lib.generators.toPretty {} config.WIP-nodejs-builder-v3.pdefs."minimal"."1.0.0".dist;
    expected = "<derivation minimal-dist>";
  };

  test_nodejs_eval_nodeModules = let
    evaled = eval ({config, ...}: {
      imports = [
        dream2nix.modules.dream2nix.WIP-nodejs-builder-v3
      ];
      WIP-nodejs-builder-v3.packageLockFile = ./package-lock.json;
    });
    inherit (evaled) config;
  in {
    expr = lib.generators.toPretty {} config.WIP-nodejs-builder-v3.pdefs."minimal"."1.0.0".prepared-dev;
    expected = "<derivation minimal-node_modules-dev>";
  };

  test_nodejs_root_info = let
    evaled = eval ({config, ...}: {
      imports = [
        dream2nix.modules.dream2nix.WIP-nodejs-builder-v3
      ];
      WIP-nodejs-builder-v3.packageLockFile = ./package-lock.json;
    });
    inherit (evaled) config;
  in {
    expr = {
      inherit
        (config.WIP-nodejs-builder-v3.pdefs."minimal"."1.0.0".info)
        initialPath
        initialState
        ;
    };
    expected = {
      initialPath = "";
      initialState = "source";
    };
  };

  # TODO: There is no prod node_modules yet.
  test_nodejs_eval_nodeModules_prod = let
    evaled = eval ({config, ...}: {
      imports = [
        dream2nix.modules.dream2nix.WIP-nodejs-builder-v3
      ];
      WIP-nodejs-builder-v3.packageLockFile = ./package-lock.json;
    });
    inherit (evaled) config;
  in {
    expr = lib.generators.toPretty {} config.WIP-nodejs-builder-v3.pdefs."minimal"."1.0.0".prepared-prod;
    expected = "<derivation minimal-node_modules-prod>";
  };
}
