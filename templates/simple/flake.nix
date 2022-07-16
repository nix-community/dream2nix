{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = inp:
    inp.dream2nix.lib.makeFlakeOutputs {
      # modify according to your supported systems
      systems = inp.dream2nix.lib.systemsFromFile ./nix_systems;
      config.projectRoot = ./.;
      source = ./.;
    };
}
