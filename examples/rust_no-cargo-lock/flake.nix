{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    src.url = "github:yusdacra/linemd/v0.4.0";
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
      settings = [
        {
          builder = "crane";
          translator = "cargo-toml";
        }
      ];
    })
    // {
      # checks.x86_64-linux.linemd = self.packages.x86_64-linux.linemd;
    };
}
