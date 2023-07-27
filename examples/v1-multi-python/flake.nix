{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.dream2nix.url = "github:nix-community/dream2nix";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    dream2nix,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        l = nixpkgs.lib // builtins;

        callModule = module:
          dream2nix.lib.evalModules {
            packageSets = {
              nixpkgs = pkgs;
            };
            modules = [
              module
              # ./lock.nix
            ];
          };

        hello = callModule ./hello;
        pypkg1 = callModule ./code1/pypkg1;
      in {
        devShell = pkgs.mkShell {
          # SITEPACKAGES = pyenv.out + "/" + pyenv.sitePackages;
          buildInputs = [
            hello
            pypkg1
          ];
        };

        packages = {
          inherit hello pypkg1;
        };
      }
    );
}
