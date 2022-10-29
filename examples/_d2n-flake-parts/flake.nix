{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
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
      imports = [dream2nix.flakeModule];
      dream2nix = {
        config.projectRoot = ./.;
        projects."ripgrep" = {
          source = src;
          settings = [{builder = "crane";}];
        };
      };
      perSystem = {
        config,
        lib,
        pkgs,
        ...
      }: let
        inherit (config.dream2nix) outputs;
      in {
        packages.ripgrep = outputs.packages.ripgrep.overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [pkgs.hello];
          postInstall = ''
            ${old.postInstall or ""}
            hello
          '';
        });
      };
    };
}
