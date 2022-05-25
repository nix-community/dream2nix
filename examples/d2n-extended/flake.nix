{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    src.url = "github:BurntSushi/ripgrep/13.0.0";
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
      config.extra = {
        subsystems.rust = {
          builders.crane-new = "${dream2nix}/src/subsystems/rust/builders/crane";
          translators.cargo-lock-new = "${dream2nix}/src/subsystems/rust/translators/cargo-lock";
        };
      };
    };
  in
    (dream2nix.makeFlakeOutputs {
      source = src;
      settings = [
        {
          builder = "crane-new";
          translator = "cargo-lock-new";
        }
      ];
    })
    // {
      checks.x86_64-linux.ripgrep = self.packages.x86_64-linux.ripgrep;
    };
}
