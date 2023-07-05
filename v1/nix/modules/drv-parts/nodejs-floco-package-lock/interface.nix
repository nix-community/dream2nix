{
  config,
  options,
  lib,
  drv-parts,
  dream2nix,
  packageSets,
  ...
}: let
  l = lib // builtins;
  t = l.types;
  cfg = config.nodejs-floco;
  floco = (import "${dream2nix.inputs.floco.outPath}/flake.nix").outputs {inherit (packageSets) nixpkgs;};
in {
  options.nodejs-floco-package-lock = l.mkOption {
    type = t.submoduleWith {
      modules = [
        "${dream2nix.inputs.floco}/modules/buildPlan"
        "${dream2nix.inputs.floco}/modules/plockToPdefs"
        "${dream2nix.inputs.floco}/modules/settings"
      ];
      specialArgs = {lib = floco.lib;};
    };
  };
}
