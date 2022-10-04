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
        (builtins.toFile "brp-new.nix" ''
          {
            builders.brp-new = {
              imports = ["${inp.dream2nix}/src/subsystems/rust/builders/build-rust-package"];
              name = "brp-new";
              subsystem = "rust";
            };
          }
        '')
        (builtins.toFile "cargo-new.nix" ''
          {
            discoverers.cargo-new = {
              imports = ["${inp.dream2nix}/src/subsystems/rust/discoverers/cargo"];
              name = "cargo-new";
              subsystem = "rust";
            };
          }
        '')
        (builtins.toFile "crates-io-new.nix" ''
          {
            fetchers.crates-io = {
              imports = ["${inp.dream2nix}/src/fetchers/crates-io"];
            };
          }
        '')
      ];
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
