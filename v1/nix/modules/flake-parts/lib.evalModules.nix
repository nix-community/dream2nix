{
  self,
  lib,
  inputs,
  ...
}: {
  flake.options.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
  };
  flake.config.lib.evalModules = args @ {
    packageSets,
    modules,
    # Ff set, returns the result coming form nixpgs.lib.evalModules as is,
    # otherwise it returns the derivation only (.config.public).
    raw ? false,
    ...
  }: let
    forawardedArgs = builtins.removeAttrs args [
      "packageSets"
      "return"
    ];

    evaluated =
      lib.evalModules
      (
        forawardedArgs
        // {
          modules =
            args.modules
            ++ [
              inputs.drv-parts.modules.drv-parts.core
            ];
          specialArgs = {
            inherit packageSets;
            dream2nix.modules.drv-parts = self.modules.drv-parts;
            drv-parts = inputs.drv-parts;
          };
        }
      );

    result =
      if raw
      then evaluated
      else evaluated.config.public;
  in
    result;
}
