{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    src.url = "github:prettier/prettier/2.4.1";
    src.flake = false;
  };

  outputs = {
    self,
    dream2nix,
    src,
  }:
    (dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      source = src;
      projects = {
        prettier = {
          name = "prettier";
          subsystem = "nodejs";
          translator = "yarn-lock";
        };
      };
    })
    // {
      # checks = self.packages;
    };
}
