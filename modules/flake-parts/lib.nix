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
    # If set, returns the result coming form nixpgs.lib.evalModules as is,
    # otherwise it returns the derivation only (.config.public).
    raw ? false,
    specialArgs ? {},
    ...
  }: let
    forawardedArgs = builtins.removeAttrs args [
      "packageSets"
      "raw"
    ];

    evaluated =
      lib.evalModules
      (
        forawardedArgs
        // {
          modules =
            args.modules
            ++ [
              self.modules.dream2nix.core
            ];
          specialArgs =
            specialArgs
            // {
              inherit packageSets;
              dream2nix.modules.dream2nix = self.modules.dream2nix;
              dream2nix.lib.evalModules = self.lib.evalModules;
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
