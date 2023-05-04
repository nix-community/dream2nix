let
  # import dream2nix
  dream2nix = import (builtins.fetchTarball "https://github.com/nix-community/dream2nix/tarball/main");

  # A setup module which is imported for each package.
  # This is used to define the location and naming of dream2nix lock files.
  # TODO: modify this according to your repo structure
  setupModule = {config, ...}: {
    # Define the root of your repo. All other paths are relative to it.
    lock.repoRoot = ./.;

    # define how a specific lock file should be called
    # This definition will produce lock files like:
    #   my-package-x86_64-linux-lock.json
    lock.lockFileRel = "/${config.name}-${config.deps.stdenv.system}-lock.json";
  };

  # evaluate package module
  my-package = dream2nix.lib.evalModules {
    # define external package sets
    packageSets = {
      nixpkgs = import <nixpkgs> {};
    };

    # load the actual package module
    modules = [
      ./my-package.nix
      setupModule
    ];
  };
in
  my-package
