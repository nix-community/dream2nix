{
  lib,
  dream2nix,
  ...
}: rec {
  importPackages = args @ {
    projectRoot,
    projectRootFile,
    packagesDir,
    ...
  }: let
    projectRoot = toString args.projectRoot;
    packagesDir = toString args.packagesDir;
    packagesDirPath =
      if lib.hasPrefix projectRoot packagesDir
      then packagesDir
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
        evalModules (forwardedArgs
          // {
            modules =
              args.modules
              or []
              ++ [
                (packagesDirPath + "/${module}")
                {
                  paths.projectRoot = projectRoot;
                  paths.projectRootFile = projectRootFile;
                  paths.package = packagesDir + "/${module}";
                }
              ];
          })
    )
    (builtins.readDir packagesDirPath);

  evalModules = args @ {
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
              dream2nix.modules.dream2nix.core
            ];
          specialArgs =
            specialArgs
            // {inherit packageSets;}
            // {
              dream2nix.modules.dream2nix = dream2nix.modules.dream2nix;
              dream2nix.overrides = dream2nix.overrides;
              dream2nix.lib.evalModules = evalModules;
              dream2nix.inputs = dream2nix.inputs;
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
