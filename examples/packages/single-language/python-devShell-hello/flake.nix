{
  description = "Example of a devShell utilizing the pip module. Run `nix develop .#devShells.x86_64-linux.hello`";

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
    pkgs = inputs.dream2nix.inputs.nixpkgs.legacyPackages.${system};
    packages.${system}.hello = dream2nix.lib.evalModules {
      packageSets.nixpkgs = pkgs;
      modules = [
        ./hello.nix
        {
          paths.projectRoot = ./.;
          # can be changed to ".git" or "flake.nix" to get rid of .project-root
          paths.projectRootFile = "flake.nix";
          paths.package = ./.;
        }
      ];
    };
  in {
    locks.${system}.hello = packages.${system}.hello.lock;
    devShells.${system}.hello = packages.${system}.hello.devShell;
  };
}
