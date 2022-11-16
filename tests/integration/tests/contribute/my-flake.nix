{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    src.url = "github:nmattia/niv";
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
        dream2nix.inputs."niv" = {
          source = src;
          projects.my-project = {
            name = "my-project";
            subsystem = "my-subsystem";
            translator = "my-pure-translator";
          };
        };
      };
    };
}
