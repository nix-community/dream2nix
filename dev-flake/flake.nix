{
  description = "Flake containing inputs/outputs not intended for overriding by the end-user";

  nixConfig = {
    extra-trusted-public-keys = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    extra-substituters = "https://nix-community.cachix.org";
  };

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    flake-compat.url = "github:nix-community/flake-compat/pull/4/head";
    flake-compat.flake = false;

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

    nix-unit.url = "github:adisbladis/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    nix-unit.inputs.flake-parts.follows = "flake-parts";

    devshell = {
      url = "github:numtide/devshell";
      flake = false;
    };
  };

  outputs = {
    self,
    devshell,
    flake-parts,
    nixpkgs,
    pre-commit-hooks,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ../modules/flake-parts/all-modules.nix
        ../pkgs/fetchPipMetadata/flake-module.nix
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    };
}
