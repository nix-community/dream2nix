{
  inputs = {
    dream2nix.url = "path:../..";
  };

  outputs = {
    self,
    dream2nix,
  } @ inp: let
    dream2nix = inp.dream2nix.lib2.init {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      config.extra = ./extra.nix;
    };
  in
    (dream2nix.makeFlakeOutputs {
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
