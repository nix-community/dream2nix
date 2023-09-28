{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? (import (../../../modules + "/default.nix")),
}: let
  eval = module:
    (lib.evalModules {
      modules = [
        dream2nix.modules.dream2nix.python-pdm
        module
      ];
      specialArgs = {
        inherit dream2nix;
        packageSets.nixpkgs = pkgs;
      };
    })
    .config;
in {
  test_pdm = let
    config = eval {
      # TODO: create fixtures
      pdm.lockfile = ./../../../examples/dream2nix-repo-flake-pdm/pdm.lock;
      pdm.pyproject = ./../../../examples/dream2nix-repo-flake-pdm/pyproject.toml;
      # groups.my-group.packages.hello = {...}: fixtures.basic-derivation;
    };
  in {
    expr = true;
    # expr = config.groups.my-group.public.hello ? drvPath;
    expected = true;
  };
}
