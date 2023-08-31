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

  _callModule = module:
    nixpkgs.lib.evalModules {
      specialArgs.dream2nix = dream2nix;
      specialArgs.packageSets.nixpkgs = nixpkgs;
      modules = [module ./settings.nix dream2nix.modules.dream2nix.core];
    };

  # like callPackage for modules
  callModule = module: (_callModule module).config.public;

  packageModuleNames = builtins.attrNames (builtins.readDir ./packages);

  packages =
    lib.genAttrs packageModuleNames
    (moduleName: callModule "${./packages}/${moduleName}");
in
  # all packages defined inside ./packages/
  packages
