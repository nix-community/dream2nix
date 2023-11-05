{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  inputs ? {},
  dream2nix ? import ../../.. inputs,
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
      pdm.lockfile = ./../../../examples/repo-flake-pdm/pdm.lock;
      pdm.pyproject = ./../../../examples/repo-flake-pdm/pyproject.toml;
    };
  in {
    expr = (lib.head (lib.attrValues config.groups.default.packages.certifi)).public ? drvPath;
    expected = true;
  };
}
