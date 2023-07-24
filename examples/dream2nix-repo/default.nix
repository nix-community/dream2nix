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

  callModule' = module:
    nixpkgs.lib.evalModules {
      specialArgs = {
        inherit dream2nix;
        packageSets = {
          inherit nixpkgs;
        };
      };
      modules = [
        dream2nix.modules.drv-parts.core
        module
        ./settings.nix
      ];
    };

  # like callPackage for modules
  callModule = module: (callModule' module).config.public;

  packageModuleNames = builtins.attrNames (builtins.readDir ./packages);

  packages =
    lib.genAttrs packageModuleNames
    (moduleName: callModule "${./packages}/${moduleName}");
in
  # all packages defined inside ./packages/
  packages
