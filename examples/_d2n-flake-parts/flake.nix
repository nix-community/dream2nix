{
  inputs = {
    dream2nix.url = "path:../..";
    nixpkgs.follows = "dream2nix/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    src.url = "github:BurntSushi/ripgrep/13.0.0";
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
        dream2nix.inputs."ripgrep" = {
          source = src;
          settings = [{builder = "crane";}];
        };
      };
    };
}
