{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  makeArgs = p:
    {
      inherit (config) systems;
      inherit (config.dream2nix) config;
    }
    // p;
in {
  config = {
    flake = l.mkMerge (
      l.map
      (p: config.dream2nix.lib.makeFlakeOutputs (makeArgs p))
      config.dream2nix.projects
    );
  };
}
