{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? (import (../../../modules + "/flake.nix")).outputs {},
}: let
  eval = module:
    lib.evalModules {
      modules = [module];
      specialArgs = {
        inherit dream2nix;
        packageSets.nixpkgs = pkgs;
      };
    };
in {
  # test if dependencies are flattened
  test_pip_flattened_dependencies = let
    evaled = eval {
      imports = [
        dream2nix.modules.drv-parts.pip
      ];
      name = "test";
      lock.content = lib.mkForce {
        fetchPipMetadata.targets.default.flask = [];
        fetchPipMetadata.targets.default.requests = [];
      };
      pip.flattenDependencies = true;
    };
    config = evaled.config;
  in {
    expr = config.pip.rootDependencies;
    expected = {
      flask = true;
      requests = true;
    };
  };

  # test if dependencies are ignored successfully in pip.rootDependencies
  test_pip_ignore_dependencies = let
    evaled = eval {
      imports = [
        dream2nix.modules.drv-parts.pip
      ];
      name = "test";
      pip.ignoredDependencies = ["requests"];
      lock.content = lib.mkForce {
        fetchPipMetadata.targets.default.test = ["requests"];
        fetchPipMetadata.targets.default.requests = [];
      };
    };
    config = evaled.config;
  in {
    expr = config.pip.targets.default ? requests;
    expected = false;
  };

  # test if root dependency is picked correctly
  test_pip_root_dependency = let
    evaled = eval {
      imports = [
        dream2nix.modules.drv-parts.pip
      ];
      name = "test";
      lock.content = lib.mkForce {
        fetchPipMetadata.targets.default.test = ["requests"];
        fetchPipMetadata.targets.default.requests = [];
      };
    };
    config = evaled.config;
  in {
    expr = config.pip.rootDependencies;
    expected = {
      requests = true;
    };
  };
}
