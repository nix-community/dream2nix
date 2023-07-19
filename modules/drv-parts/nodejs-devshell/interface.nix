{
  config,
  lib,
  dream2nix,
  packageSets,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.nodejs-devshell = {
    nodeModules = l.mkOption {
      description = "drv-parts module for the node_modules derivation";
      type = t.submoduleWith {
        specialArgs = {inherit packageSets dream2nix;};
        modules = [
          dream2nix.modules.drv-parts.core
          dream2nix.modules.drv-parts.nodejs-node-modules
        ];
      };
    };
  };
}
