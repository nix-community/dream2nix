{
  description = "My flake with dream2nix packages";

  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    self,
    dream2nix,
    nixpkgs,
    ...
  }: let
    system = "x86_64-linux";
    inherit (nixpkgs) lib;
  in {
    # all packages defined inside ./packages/
    packages = let
      module = {
        config,
        lib,
        dream2nix,
        ...
      }: {
        imports = [
          dream2nix.modules.dream2nix.WIP-groups
        ];

        # Overrides for all package sets
        overrides = {};

        # We can define various package sets
        groups = {
          non-overridden-set = {
            overrides = lib.mkForce {};
          };
          # By default, a set has a packages attribute.
          # Additional modules can add support for creating environments.
          python-set = {
            overrides = {};
            devShell = {};
            packages = {};
          };
          nodejs-set = {
            # ...
          };

          final-set = {
            imports = [
              dream2nix.modules.dream2nix.packages
              dream2nix.modules.dream2nix.python-packages
              dream2nix.modules.dream2nix.symlinked-env
              dream2nix.modules.dream2nix.dev-shell
            ];
            packages = {
              inherit
                (config.groups.python-set)
                requests
                aiohttp
                ;
            };
            symlinked-env = {type = "derivation";};
            dev-shell = {type = "derivation";};
            # populated automatically
            public.symlinked-env = {type = "derivation";};
            public.dev-shell = {type = "derivation";};
          };
        };
      };
      evaled = lib.evalModules {modules = [module];};
      inherit (evaled.config.groups.python-set.public) packages;
      inherit (evaled.config.packages-sets.python-set.public) env;
      symlinkedEnv = evaled.config.packge-sets.final-set.public.symlinked-env;
    in {
      inherit
        (packages)
        hello
        torch
        ;
    };
  };
}
