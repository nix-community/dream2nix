{
  description = "My flake with dream2nix packages";

  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    self,
    dream2nix,
    nixpkgs,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    lib = nixpkgs.lib;
    packageModuleNames = builtins.attrNames (builtins.readDir ./packages);
  in {
    # all packages defined inside ./packages/
    packages.${system} =
      lib.genAttrs packageModuleNames
      (moduleName:
        dream2nix.lib.evalModules {
          modules = ["${./packages}/${moduleName}" ./settings.nix];
          packageSets.nixpkgs = pkgs;
          specialArgs.self = self;
        });
  };
}
