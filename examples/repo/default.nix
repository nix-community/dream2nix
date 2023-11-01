{
  dream2nixSource ?
    builtins.fetchTarball {
      url = "https://github.com/nix-community/dream2nix/tarball/main";
      # sha256 = "";
    },
  pkgs ? import (import dream2nixSource {}).inputs.nixpkgs {},
}: let
  dream2nix = import dream2nixSource {};
  # all packages defined inside ./packages/
  packages = dream2nix.lib.importPackages {
    projectRoot = ./.;
    # can be changed to ".git" to get rid of .project-root
    projectRootFile = ".project-root";
    packagesDir = ./packages;
    packageSets.nixpkgs = pkgs;
  };
in
  # all packages defined inside ./packages/
  packages
