{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = {
    self,
    dream2nix,
  } @ inputs: let
    dream2nix = inputs.dream2nix.lib.init {
      # modify according to your supported systems
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
    };
  in
    dream2nix.makeFlakeOutputs {
      source = ./.;
    };
}
