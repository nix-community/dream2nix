{
  self,
  lib,
  inputs,
  ...
}: {
  flake.options.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
  };
  flake.config.lib.importPackages = args @ {
    projectRoot,
    projectRootFile,
    packagesDir,
    ...
  }: let
    packagesDirPath =
      if ! builtins.isString packagesDir
      then throw "packagesDir must be a string"
      else projectRoot + "/${packagesDir}";
    forwardedArgs = builtins.removeAttrs args [
      "projectRoot"
      "projectRootFile"
      "packagesDir"
    ];
  in
    lib.mapAttrs
    (
      module: type:
        self.lib.evalModules (forwardedArgs
          // {
            modules =
              args.modules
              or []
              ++ [
                (packagesDirPath + "/${module}")
                {
                  paths.projectRoot = projectRoot;
                  paths.projectRootFile = projectRootFile;
                  paths.package = "/${packagesDir}/${module}";
                }
              ];
          })
    )
    (builtins.readDir packagesDirPath);

  flake.config.lib.evalModules = args @ {
    packageSets,
    modules,
    # If set, returns the result coming form nixpkgs.lib.evalModules as is,
    # otherwise it returns the derivation only (.config.public).
    raw ? false,
    specialArgs ? {},
    ...
  }: let
    forwardedArgs = builtins.removeAttrs args [
      "packageSets"
      "raw"
    ];

    evaluated =
      lib.evalModules
      (
        forwardedArgs
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
              dream2nix.overrides = self.overrides;
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
