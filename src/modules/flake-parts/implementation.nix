{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  d2n = config.dream2nix;
  makeArgs = p:
    {
      inherit (config) systems;
      inherit (d2n) config;
    }
    // p;
  outputs = d2n.lib.dlib.mergeFlakes (
    l.map
    (p: d2n.lib.makeFlakeOutputs (makeArgs p))
    (l.attrValues d2n.projects)
  );
in {
  config = {
    flake =
      # make attrs default, so that users can override them without
      # needing to use lib.mkOverride (usually, lib.mkForce)
      l.mapAttrsRecursiveCond
      d2n.lib.dlib.isNotDrvAttrs
      (_: l.mkDefault)
      outputs;
    dream2nix.outputs = outputs;
    perSystem = {
      config,
      system,
      ...
    }: let
      # get output attrs that have systems
      systemizedOutputs =
        l.mapAttrs
        (_: attrs: attrs.${system})
        (
          l.filterAttrs
          (_: attrs: l.isAttrs attrs && l.hasAttr system attrs)
          outputs
        );
    in {
      config = {
        dream2nix.outputs = systemizedOutputs;
      };
    };
  };
}
