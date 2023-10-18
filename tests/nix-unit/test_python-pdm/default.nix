{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? ((import (../../../modules + "/flake.nix")).outputs inputs),
  inputs ? (import (../../../modules + "/default.nix")).inputs,
}: let
  eval = module:
    (lib.evalModules {
      modules = [
        dream2nix.modules.dream2nix.WIP-python-pdm
        module
      ];
      specialArgs = {
        dream2nix = dream2nix // {inherit inputs;};
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
    };
  in {
    expr = lib.head (lib.attrValues config.groups.default.public.packages.certifi) ? drvPath;
    expected = true;
  };
}
