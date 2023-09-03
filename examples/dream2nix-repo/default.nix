{
  dream2nixSource ?
    builtins.fetchTarball {
      url = "https://github.com/nix-community/dream2nix/tarball/main";
      # sha256 = "";
    },
}: let
  dream2nix = import dream2nixSource;
  nixpkgs = import dream2nix.inputs.nixpkgs {};
  lib = nixpkgs.lib;

  packageModuleNames = builtins.attrNames (builtins.readDir ./packages);

  packages =
    lib.genAttrs packageModuleNames
    (moduleName:
      dream2nix.lib.evalModules {
        modules = ["${./packages}/${moduleName}" ./settings.nix];
        packageSets.nixpkgs = nixpkgs;
      });
in
  # all packages defined inside ./packages/
  packages
