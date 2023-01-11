{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    src.url = "github:prettier/prettier/2.4.1";
    src.flake = false;
  };

  outputs = {
    self,
    dream2nix,
    flake-parts,
    src,
    ...
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = ["x86_64-linux"];
      imports = [dream2nix.flakeModuleBeta];

      perSystem = {config, ...}: {
        # define an input for dream2nix to generate outputs for
        dream2nix.inputs."prettier" = {
          source = src;
          projects = {
            prettier = {
              subsystem = "nodejs";
              translator = "yarn-lock";
            };
          };
        };
      };
    };
}
