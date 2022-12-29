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
        (_: args: instance.dream2nix-interface.makeOutputs args)
        config.dream2nix.inputs;

      getAttrsFromOutputs = attrName:
        l.mapAttrsToList
        (_: output: mkDefaultRecursive output.${attrName} or {})
        outputs;

      combinedResolveImpure =
        instance.utils.writePureShellScriptBin
        "resolve"
        []
        (l.concatStringsSep "\n" (
          l.mapAttrsToList
          (_: output: "${output.packages.resolveImpure}/bin/resolve")
          outputs
        ));
    in {
      config = {
        dream2nix = {inherit instance outputs;};

        # TODO(yusdacra): maybe we could rename outputs with the same name to avoid collisions?
        packages = l.mkMerge (
          getAttrsFromOutputs "packages"
          ++ [{resolveImpure = l.mkForce combinedResolveImpure;}]
        );

        devShells = l.mkMerge (getAttrsFromOutputs "devShells");
      };
    };
  };
}
