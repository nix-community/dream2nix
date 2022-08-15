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
  } @ inp:
    (dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      config.modules = [
        (builtins.toFile "cargo-toml-new.nix" ''
          {
            translators.cargo-toml-new = {
              imports = ["${inp.dream2nix}/src/subsystems/rust/translators/cargo-toml"];
              name = "cargo-toml-new";
              subsystem = "rust";
            };
          }
        '')
      ];
      config.extra = {
        subsystems.rust = {
          builders.brp-new = "${inp.dream2nix}/src/subsystems/rust/builders/build-rust-package";
          discoverers.default = "${inp.dream2nix}/src/subsystems/rust/discoverers/default";
        };
        fetchers.crates-io = "${inp.dream2nix}/src/fetchers/crates-io";
      };
      source = src;
      settings = [
        {
          builder = "brp-new";
          translator = "cargo-toml-new";
        }
      ];
    })
    // {
      checks.x86_64-linux.ripgrep = self.packages.x86_64-linux.ripgrep;
    };
}
