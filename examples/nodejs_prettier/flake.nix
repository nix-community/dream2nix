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
  } @ inp: let
    d2n-flake = dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      source = src;
    };

    overrideDevShells = {
      devShells =
        d2n-flake.devShells
        // {
          x86_64-linux =
            d2n-flake.devShells.x86_64-linux
            // {
              default =
                d2n-flake.devShells.x86_64-linux.default.overrideAttrs
                (old: {
                  buildInputs =
                    old.buildInputs
                    ++ [
                      self.packages.x86_64-linux.hello
                    ];
                });
            };
        };
    };

    addChecks = {
      checks.x86_64-linux.prettier = self.packages.x86_64-linux.prettier;
    };
  in
    d2n-flake // overrideDevShells // addChecks;
}
