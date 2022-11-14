{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    src.url = "github:davhau/cabal2json/plan-json";
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
          translator = "cabal-plan";
        }
      ];
    })
    // {
      # checks.x86_64-linux.cabal2json = self.packages.x86_64-linux.cabal2json.overrideAttrs (old: {
      #   doCheck = false;
      # });
    };
}
