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

      outputsRaw =
        l.mapAttrs
        (_: args: instance.makeOutputs args)
        config.dream2nix.inputs;

      getAttrFromOutputs = attrName:
        d2n.lib.dlib.mergeFlakes (
          l.mapAttrsToList
          (_: attrs: attrs.${attrName})
          outputsRaw
        );
    in {
      config = {
        dream2nix = {
          inherit instance;
          outputs =
            # if only one input was defined, then only export outputs from
            # that since there is nothing else
            if l.length (l.attrNames outputsRaw) != 1
            then outputsRaw
            else l.head (l.attrValues outputsRaw);
        };
        devShells = mkDefaultRecursive (getAttrFromOutputs "devShells");
        packages = mkDefaultRecursive (getAttrFromOutputs "packages");
      };
    };
  };
}
