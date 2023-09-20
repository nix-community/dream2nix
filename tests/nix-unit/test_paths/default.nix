{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? (import (../../../modules + "/flake.nix")).outputs {},
}: let
  eval = module:
    (lib.evalModules {
      modules = [
        dream2nix.modules.dream2nix.core
        module
      ];
      specialArgs = {
        inherit dream2nix;
        packageSets.nixpkgs = pkgs;
      };
    })
    .config;
in {
  test_package_in_root_1 = let
    config = eval {
      paths.projectRoot = "${./.}";
      paths.package = "${./.}";
    };
  in {
    expr = {inherit (config.paths) projectRoot package;};
    expected = {
      projectRoot = "${./.}";
      package = "./.";
    };
  };

  test_package_in_root_2 = let
    config = eval {
      paths.projectRoot = "${./.}";
      paths.package = "./.";
    };
  in {
    expr = {inherit (config.paths) projectRoot package;};
    expected = {
      projectRoot = "${./.}";
      package = "./.";
    };
  };

  test_package_in_subdir_1 = let
    config = eval {
      paths.projectRoot = "${./.}";
      paths.package = "${./.}/package";
    };
  in {
    expr = {inherit (config.paths) projectRoot package;};
    expected = {
      projectRoot = "${./.}";
      package = "./package";
    };
  };

  test_package_in_subdir_2 = let
    config = eval {
      paths.projectRoot = "${./.}";
      paths.package = "./package";
    };
  in {
    expr = {inherit (config.paths) projectRoot package;};
    expected = {
      projectRoot = "${./.}";
      package = "./package";
    };
  };

  test_package_in_subdir_3 = let
    self = /nix/store/some/path;
    config = eval {
      paths.projectRoot = self;
      paths.package = self + /package;
    };
  in {
    expr = {inherit (config.paths) projectRoot package;};
    expected = {
      projectRoot = self;
      package = "./package";
    };
  };
}
