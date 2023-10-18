{
  description = "My flake with dream2nix packages";

  inputs = {
    dream2nix.url = "github:nix-community/dream2nix?dir=modules";
    nixpkgs.follows = "dream2nix/nixpkgs";
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
    evaled = lib.evalModules {
      modules = [module];
      specialArgs.dream2nix = dream2nix;
      specialArgs.packageSets.nixpkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
  in {
    packages.${system}.requests = evaled.config.groups.default.public.packages.requests."2.31.0";
  };
}
