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
      # nixpkgs could be imported manually here with overrides etc.
      (system: inp.dream2nix.inputs.nixpkgs.legacyPackages.${system})
      ["x86_64-linux" "aarch64-linux"];
  in
    inp.dream2nix.lib.makeFlakeOutputs {
      pkgs = allPkgs;
      config.projectRoot = ./.;
      source = inp.src;
      projects = ./projects.toml;
    };
}
