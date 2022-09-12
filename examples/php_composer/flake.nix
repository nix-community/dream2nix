{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    src.url = "github:composer/composer";
    src.flake = false;
  };

  outputs = {
    self,
    dream2nix,
    src,
  } @ inp:
    (dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      source = src;
      settings = [];
    })
    // {
      # checks = self.packages;
    };
}
