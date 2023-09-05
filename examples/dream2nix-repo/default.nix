{
  dream2nixSource ?
    builtins.fetchTarball {
      url = "https://github.com/nix-community/dream2nix/tarball/main";
      # sha256 = "";
    },
}: let
  dream2nix = import dream2nixSource;
  nixpkgs = import dream2nix.inputs.nixpkgs {};
  # all packages defined inside ./packages/
  packages = dream2nix.lib.importPackages {
    projectRoot = ./.;
    # can be changed to ".git" to get rid of .project-root
    projectRootFile = ".project-root";
    packagesDir = "/packages";
    packageSets.nixpkgs = nixpkgs;
  };
in
  # all packages defined inside ./packages/
  packages
