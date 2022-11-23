{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    src.url = "https://files.pythonhosted.org/packages/5a/86/5f63de7a202550269a617a5d57859a2961f3396ecd1739a70b92224766bc/aiohttp-3.8.1.tar.gz";
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
          # optionally define python version
          subsystemInfo.pythonVersion = "3.8";
          # optionally define extra setup requirements;
          subsystemInfo.extraSetupDeps = ["cython > 0.29"];
        }
      ];
    })
    // {
      checks.x86_64-linux.aiohttp = self.packages.x86_64-linux.main;
    };
}
