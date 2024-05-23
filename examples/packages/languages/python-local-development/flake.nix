{
  description = "My flake with dream2nix packages";

  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
  };

  outputs = inputs @ {
    self,
    dream2nix,
    nixpkgs,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system}.default = dream2nix.lib.evalModules {
      packageSets.nixpkgs = pkgs;
      modules = [
        ./default.nix
        {
          paths.projectRoot = ./.;
          # can be changed to ".git" or "flake.nix" to get rid of .project-root
          paths.projectRootFile = "flake.nix";
          paths.package = ./.;
        }
      ];
    };
    devShells.${system}.default = pkgs.mkShell {
      # inherit from the dream2nix generated dev shell
      inputsFrom = [self.packages.${system}.default.devShell];
      # add extra packages
      packages = [
        pkgs.hello
      ];
    };
  };
}
