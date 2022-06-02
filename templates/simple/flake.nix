{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = inp:
    inp.dream2nix.lib.makeFlakeOutputs {
      # modify according to your supported systems
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      source = ./.;
    };
}
