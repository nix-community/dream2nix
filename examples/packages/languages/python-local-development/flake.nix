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
    pkgs = inputs.dream2nix.inputs.nixpkgs.legacyPackages.${system};
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
        {
          # TODO rewrite interface to name -> bool or path
          pip.editables.my_tool = {
            path = "/home/phaer/src/dream2nix/examples/packages/languages/python-local-development";
          };
        }
      ];
    };
    devShells.${system}.default = pkgs.mkShell {
      shellHook = ''
        ${self.packages.${system}.default.config.pip.editablesShellHook}
      '';
    };
  };
}
