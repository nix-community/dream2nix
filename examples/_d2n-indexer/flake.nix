{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
  };

  outputs = inp:
    (inp.dream2nix.lib.makeFlakeOutputsForIndexes {
      source = ./.;
      systems = ["x86_64-linux"];
      indexNames = ["libraries-io"];
      packageOverrides = {
        "^.*$".disable-build = {
          buildScript = ":";
        };
      };
      overrideOutputs = {
        mkIndexApp,
        prevOutputs,
        ...
      }: {
        apps =
          prevOutputs.apps
          // {
            libraries-io = mkIndexApp {
              name = "libraries-io";
              input = {
                platform = "npm";
                number = 5;
              };
            };
          };
      };
    })
    // {
      checks = inp.self.packages;
    };
}
