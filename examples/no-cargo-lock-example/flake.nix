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
  } @ inp: let
    dream2nix = inp.dream2nix.lib2.init {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
    };
  in
    (dream2nix.makeFlakeOutputs {
      source = src;
      settings = [{builder = "crane";}];
    })
    // {
      #checks.x86_64-linux.rand = self.packages.x86_64-linux.rand;
    };
}
