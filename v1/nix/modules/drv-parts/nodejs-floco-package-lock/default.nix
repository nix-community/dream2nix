{
  config,
  lib,
  dream2nix,
  packageSets,
  ...
}: let
  l = lib // builtins;
  floco = (import "${dream2nix.inputs.floco.outPath}/flake.nix").outputs {inherit (packageSets) nixpkgs;};
  cfg = config.nodejs-floco-package-lock;
in {
  imports = [
    ./interface.nix
  ];

  config.nodejs-floco.pdefs = cfg.exports;
}
