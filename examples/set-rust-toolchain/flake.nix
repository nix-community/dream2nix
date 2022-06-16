{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
    dream2nix.url = "github:nix-community/dream2nix";
    dream2nix.inputs.nixpkgs.follows = "nixpkgs";
    src.url = "github:BurntSushi/ripgrep/13.0.0";
    src.flake = false;
  };

  outputs = {
    self,
    dream2nix,
    fenix,
    src,
    ...
  } @ inp: let
    system = "x86_64-linux";
    toolchain = fenix.packages.${system}.minimal.toolchain;
  in
    (dream2nix.lib.makeFlakeOutputs {
      systems = [system];
      config.projectRoot = ./.;
      source = src;
      settings = [
        {
          builder = "crane";
          translator = "cargo-lock";
        }
      ];
      packageOverrides = {
        # override all packages and set a toolchain
        "^.*" = {
          set-toolchain.overrideRustToolchain = old: {cargo = toolchain;};
          check-toolchain-version.overrideAttrs = old: {
            buildPhase = ''
              currentCargoVersion="$(cargo --version)"
              customCargoVersion="$(${toolchain}/bin/cargo --version)"
              if [[ "$currentCargoVersion" != "$customCargoVersion" ]]; then
                echo "cargo version is $currentCargoVersion but it needs to be $customCargoVersion"
                exit 1
              fi
              ${old.buildPhase or ""}
            '';
          };
        };
      };
    })
    // {
      checks.x86_64-linux.ripgrep = self.packages.x86_64-linux.ripgrep;
    };
}
