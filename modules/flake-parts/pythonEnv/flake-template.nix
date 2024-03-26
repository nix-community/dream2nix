{
  description = "My flake with dream2nix packages";

  inputs = {
    dream2nix.url = "github:nix-community/dream2nix/pythonEnv";
    nixpkgs.follows = "dream2nix/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {
    self,
    dream2nix,
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      perSystem = {
        pkgs,
        system,
        ...
      }: let
        module = {
          config,
          dream2nix,
          ...
        }: {
          imports = [
            dream2nix.modules.dream2nix.WIP-python-pdm
          ];
          deps = {nixpkgs, ...}: {
            python = nixpkgs.__PYTHON_ATTR__;
          };
          pdm.lockfile = ./pdm.lock;
          pdm.pyproject = ./pyproject.toml;
          mkDerivation = {
            src = ./.;
          };
        };

        package = dream2nix.lib.evalModules {
          packageSets.nixpkgs = inputs.nixpkgs.legacyPackages.${system};
          modules = [
            module
            {
              paths.projectRoot = ./.;
              paths.projectRootFile = "flake.nix";
              paths.package = ./.;
            }
          ];
        };
      in {
        devShells.default = package.devShell;
      };
    };
}
