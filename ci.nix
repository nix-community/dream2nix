let
  b = builtins;
  flakeCompatSrc = b.fetchurl "https://raw.githubusercontent.com/edolstra/flake-compat/12c64ca55c1014cdc1b16ed5a804aa8576601ff2/default.nix";
  flake = (import flakeCompatSrc {src = ./.;}).defaultNix;
  pkgs = import flake.inputs.nixpkgs {};
  recurseIntoAll = b.mapAttrs (name: val: pkgs.recurseIntoAttrs val);

  dream2nix-repo = import ./examples/dream2nix-repo {
    dream2nixSource = ./.;
    inherit pkgs;
  };

  dream2nix-repo-flake = (import ./examples/dream2nix-repo-flake/flake.nix).outputs {
    self = dream2nix-repo-flake;
    dream2nix = flake;
    nixpkgs = flake.inputs.nixpkgs;
  };
in
  recurseIntoAll {
    inherit dream2nix-repo dream2nix-repo-flake;
    checks = flake.checks.x86_64-linux;
    devShells = flake.devShells.x86_64-linux;
    packages = flake.packages.x86_64-linux;
  }
