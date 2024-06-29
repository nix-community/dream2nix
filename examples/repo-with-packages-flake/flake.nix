{
  # This example flake.nix is pretty generic and the same for all
  # examples, except when they define devShells or extra packages.
  description = "Dream2nix example flake";

  # We import the latest commit of dream2nix main branch and instruct nix to
  # re-use the nixpkgs revision referenced by dream2nix.
  # This is what we test in CI with, but you can generally refer to any
  # recent nixpkgs commit here.
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
  };

  outputs = {
    self,
    dream2nix,
    nixpkgs,
  }: let
    # A helper that helps us define the attributes below for
    # all systems we care about.
    eachSystem = nixpkgs.lib.genAttrs [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  in {
    packages = eachSystem (system:
      dream2nix.lib.importPackages {
        # All packages defined in ./packages/<name> are automatically added to the flake outputs
        # e.g., 'packages/hello/default.nix' becomes '.#packages.hello'
        projectRoot = ./.;
        # can be changed to ".git" or "flake.nix" to get rid of .project-root
        projectRootFile = "flake.nix";
        packagesDir = ./packages;
        packageSets.nixpkgs = nixpkgs.legacyPackages.${system};
      });
  };
}
