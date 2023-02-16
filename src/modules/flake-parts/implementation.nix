{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  d2n = config.dream2nix;
in {
  config = {
    perSystem = {
      config,
      pkgs,
      ...
    }: let
      instance = d2n.lib.init {
        inherit pkgs;
        inherit (d2n) config;
      };

      outputs =
        l.mapAttrs
        (_: args: instance.dream2nix-interface.makeOutputs args)
        config.dream2nix.inputs;
    in {
      config = {
        dream2nix = {inherit instance outputs;};
      };
    };
  };
}
