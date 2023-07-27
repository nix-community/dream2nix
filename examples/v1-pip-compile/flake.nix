{
  # NOTE: Is flake-utils still the way to go?
  inputs.flake-utils.url = "github:numtide/flake-utils";
  # inputs.dream2nix.url = "github:nix-community/dream2nix";
  inputs.dream2nix.url = "../..";

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

        setupModule = {config, ...}: {
          # Define the root of your repo. All other paths are relative to it.
          # NOTE: This is ignore for the lockFileRel below.
          lock.repoRoot = ./.;

          # Define how a specific lock file should be called
          # This definition will produce lock files like:
          #   my-package-x86_64-linux-lock.json
          #
          # NOTE: Can we get this relative to current file?
          lock.lockFileRel = "/${config.name}-${config.deps.stdenv.system}-lock.json";
        };

        callModule = module:
          dream2nix.lib.evalModules {
            packageSets = {
              nixpkgs = pkgs;
            };
            modules = [
              module
              setupModule
            ];
          };

        callModuleNoLock = module:
          dream2nix.lib.evalModules {
            packageSets = {
              nixpkgs = pkgs;
            };
            modules = [
              module
            ];
          };

        hello = callModuleNoLock ./hello;
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
