{
  inputs = {
    dream2nix.url = "path:../../.";
    src.url = "github:rust-random/rand";
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
      checks.x86_64-linux.rand = self.packages.x86_64-linux.rand;
    };
}
