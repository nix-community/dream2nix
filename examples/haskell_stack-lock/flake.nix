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
  } @ inp:
    (dream2nix.lib.makeFlakeOutputs {
      pkgs = dream2nix.inputs.nixpkgs.legacyPackages.x86_64-linux;
      source = src;
      config.projectRoot = ./.;
      settings = [
        {
          # A ghc version must be specified for stack lock based builds
          subsystemInfo.ghcVersion = 8107;
        }
      ];
    })
    // {
      # checks = self.packages;
    };
}
