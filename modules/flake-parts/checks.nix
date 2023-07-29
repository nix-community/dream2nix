# evaluate packages from `/**/modules/drvs` and export them via `flake.packages`
{
  self,
  inputs,
  ...
}: {
  perSystem = {
    system,
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit
      (lib)
      mapAttrs'
      flip
      ;
    inherit
      (builtins)
      mapAttrs
      readDir
      ;

    # A module imported into every package setting up the eval cache
    setup = {config, ...}: {
      lock.lockFileRel = "/modules/drvs/${config.name}/lock-${system}.json";
      lock.repoRoot = self;
      eval-cache.cacheFileRel = "/modules/drvs/${config.name}/cache-${system}.json";
      eval-cache.repoRoot = self;
      eval-cache.enable = true;
      deps.npm = inputs.nixpkgs.legacyPackages.${system}.nodejs.pkgs.npm.override (old: rec {
        version = "8.19.4";
        src = builtins.fetchTarball {
          url = "https://registry.npmjs.org/npm/-/npm-${version}.tgz";
          sha256 = "0xmvjkxgfavlbm8cj3jx66mlmc20f9kqzigjqripgj71j6b2m9by";
        };
      });
    };

    # evaluates the package behind a given module
    makeDrv = module: let
      evaled = lib.evalModules {
        modules = [
          self.modules.drv-parts.core
          module
          setup
        ];
        specialArgs.packageSets = {
          nixpkgs = inputs.nixpkgs.legacyPackages.${system};
          writers = config.writers;
        };
        specialArgs.dream2nix = self;
      };
    in
      evaled.config.public;

    examples = readDir (self + /examples/dream2nix-packages);

    exampleModules =
      flip mapAttrs examples
      (name: _: self + /examples/dream2nix-packages + "/${name}");

    allModules' = self.modules.drvs // exampleModules;

    allModules = flip mapAttrs' allModules' (name: module: {
      name = "example-package-${name}";
      value = module;
    });
  in {
    # map all modules in ../drvs to a package output in the flake.
    checks =
      lib.mapAttrs (_: drvModule: makeDrv drvModule)
      allModules;
  };
}
