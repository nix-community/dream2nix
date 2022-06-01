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

    allPkgs =
      l.map
      (system: inp.nixpkgs.legacyPackages.${system})
      ["x86_64-linux" "aarch64-linux"];

    initD2N = pkgs:
      inp.dream2nix.lib.init {
        inherit pkgs;
        config.projectRoot = ./.;
      };

    makeOutputs = pkgs: let
      outputs = (initD2N pkgs).makeOutputs {
        source = inp.src;
        settings = [
          {
            builder = "build-rust-package";
            translator = "cargo-lock";
          }
        ];
      };
    in rec {
      packages.${pkgs.system} = outputs.packages;
      checks.${pkgs.system} = {
        inherit (outputs.packages) ripgrep;
      };
    };

    allOutputs = l.map makeOutputs allPkgs;
    outputs = l.foldl' l.recursiveUpdate {} allOutputs;
  in
    outputs;
}
