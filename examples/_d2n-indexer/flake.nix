{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
  };

  outputs = inp:
    (inp.dream2nix.lib.makeFlakeOutputsForIndexes {
      source = ./.;
      systems = ["x86_64-linux"];
      indexes = {
        libraries-io = {
          platform = "npm";
          number = 5;
        };
        crates-io = {};
      };
      packageOverrides = {
        "^.*$".disable-build = {
          buildScript = ":";
        };
      };
    })
    // {
      checks = inp.self.packages;
    };
}
