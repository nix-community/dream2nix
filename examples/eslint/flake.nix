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
  } @ inp:
    (dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      source = src;
      settings = [
        {
          subsystemInfo.noDev = true;
        }
      ];
    })
    // {
      checks = self.packages;
    };
}
