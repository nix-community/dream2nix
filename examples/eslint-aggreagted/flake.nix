{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    src.url = "https://registry.npmjs.org/eslint/-/eslint-8.4.1.tgz";
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
          aggregate = true;
        }
      ];
    })
    // {
      checks = self.packages;
    };
}
