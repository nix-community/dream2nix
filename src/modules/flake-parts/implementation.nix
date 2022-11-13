{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  d2n = config.dream2nix;

  # make attrs default, so that users can override them without
  # needing to use lib.mkOverride (usually, lib.mkForce)
  mkDefaultRecursive = attrs:
    l.mapAttrsRecursiveCond
    d2n.lib.dlib.isNotDrvAttrs
    (_: l.mkDefault)
    attrs;
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
        (_: args: instance.makeOutputs args)
        config.dream2nix.inputs;

      getAttrFromOutputs = attrName:
        l.mkMerge (
          l.mapAttrsToList
          (_: output: mkDefaultRecursive output.${attrName} or {})
          outputs
        );
    in {
      config = {
        dream2nix = {inherit instance outputs;};
        # TODO(yusdacra): we could combine all the resolveImpure here if there are multiple
        # TODO(yusdacra): maybe we could rename outputs with the same name to avoid collisions?
        packages = getAttrFromOutputs "packages";
        devShells = getAttrFromOutputs "devShells";
      };
    };
  };
}
