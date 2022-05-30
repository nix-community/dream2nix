{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    dream2nix.url = "path:../..";
    dream2nix.inputs.nixpkgs.follows = "nixpkgs";
    src.url = "github:BurntSushi/ripgrep/13.0.0";
    src.flake = false;
  };

  outputs = inp: let
    l = inp.nixpkgs.lib // builtins;

    systems = ["x86_64-linux" "aarch64-linux"];

    makeOutputsForSystem = system: let
      pkgs = inp.nixpkgs.legacyPackages.${system};
      d2n = inp.dream2nix.lib.init {
        inherit pkgs;
        config.projectRoot = ./.;
      };
      projectOutputs = d2n.makeOutputs {
        source = inp.src;
        settings = [
          {
            builder = "build-rust-package";
            translator = "cargo-lock";
          }
        ];
      };
    in rec {
      packages.${system} = projectOutputs.packages;
      checks.${system} = {
        inherit (projectOutputs.packages) ripgrep;
      };
    };
    outputsForSystems = l.map makeOutputsForSystem systems;
    outputs = l.foldl' l.recursiveUpdate {} outputsForSystems;
  in
    outputs;
}
