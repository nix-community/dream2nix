{
  inputs = {
    dream2nix.url = "path:../..";
  };

  outputs = {
    self,
    dream2nix,
  } @ inp:
    (dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      config.extra = ./extra.nix;
      config.modules = [
        ./discoverers.nix
        ./translators.nix
        ./builders.nix
      ];
      source = ./.;
      settings = [
        {
          builder = "dummy";
          translator = "dummy";
        }
      ];
    })
    // {
      checks.x86_64-linux.hello = self.packages.x86_64-linux.hello;
    };
}
