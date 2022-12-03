{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    src.url = "github:python-poetry/poetry";
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

      perSystem = {
        config,
        system,
        ...
      }: {
        # define an input for dream2nix to generate outputs for
        dream2nix.inputs."my-project" = {
          source = src;
          projects.my-project = {
            name = "my-project";
            subsystem = "python";
            translator = "poetry";
            subsystemInfo.system = system;
            subsystemInfo.pythonVersion = "3.10";
          };
        };
      };
    };
}
