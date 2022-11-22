{
  inputs = {
    dream2nix.url = "path:../..";
    src.url = "github:yusdacra/linemd/v0.4.0";
    src.flake = false;
  };

  outputs = inp: let
    l = inp.dream2nix.inputs.nixpkgs.lib // builtins;

    allPkgs =
      l.map
      (system: inp.dream2nix.inputs.nixpkgs.legacyPackages.${system})
      ["x86_64-linux" "aarch64-linux"];

    initD2N = pkgs:
      inp.dream2nix.lib.init {
        inherit pkgs;
        config.projectRoot = ./.;
      };

    makeOutputs = pkgs: let
      outputs = (initD2N pkgs).dream2nix-interface.makeOutputs {
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
      # checks.${pkgs.system} = {
      #   inherit (outputs.packages) linemd;
      # };
    };

    allOutputs = l.map makeOutputs allPkgs;
    outputs = l.foldl' l.recursiveUpdate {} allOutputs;
  in
    outputs;
}
