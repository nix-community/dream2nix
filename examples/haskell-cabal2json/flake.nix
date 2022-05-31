{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    src.url = "github:NorfairKing/cabal2json";
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
      settings = [
        {
          subsystemInfo.noDev = true;
        }
      ];
    })
    // {
      # checks = self.packages;
    };
}
