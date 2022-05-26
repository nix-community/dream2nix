{
  inputs = {
    dream2nix.url = "path:../..";
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
          builders.crane-new = "${inp.dream2nix}/src/subsystems/rust/builders/crane";
          translators.cargo-lock-new = "${inp.dream2nix}/src/subsystems/rust/translators/cargo-lock";
          discoverers.default = "${inp.dream2nix}/src/subsystems/rust/discoverers/default";
        };
        fetchers.crates-io = "${inp.dream2nix}/src/fetchers/crates-io";
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
