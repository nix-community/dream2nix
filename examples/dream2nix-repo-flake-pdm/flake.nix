{
  description = "My flake with dream2nix packages";

  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    self,
    dream2nix,
    nixpkgs,
    ...
  }: let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    module = {
      config,
      lib,
      dream2nix,
      ...
    }: {
      imports = [
        dream2nix.modules.dream2nix.WIP-python-pdm
      ];
      pdm.lockfile = ./pdm.lock;
      pdm.pyproject = ./pyproject.toml;
      pdm.pythonInterpreter = nixpkgs.legacyPackages.python3;
    };
    evaled = lib.evalModules {modules = [module];};
    defaultPackage = evaled.config.groups.default.public.packages.my-package;
  in {
    packages.${system}.default = defaultPackage;
  };
}
