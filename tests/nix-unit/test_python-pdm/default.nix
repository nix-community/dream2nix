{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? import ../../../. inputs,
  inputs ? (import ../../../.).inputs,
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
      pdm.lockfile = ./../test_python-pdm-lib/fixtures/pdm-example1.lock;
      pdm.pyproject = ./../test_python-pdm-lib/fixtures/pyproject.toml;
    };
  in {
    expr = (lib.head (lib.attrValues config.groups.default.packages.certifi)).public ? drvPath;
    expected = true;
  };
}
