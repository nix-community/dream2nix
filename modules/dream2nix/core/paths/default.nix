{
  config,
  lib,
  ...
}: {
  imports = [
    ./interface.nix
    ../deps
  ];
  deps = {nixpkgs, ...}:
    lib.mapAttrs (_: opt: lib.mkOverride 1003 opt) {
      python3 = nixpkgs.python3;
      replaceVarsWith = nixpkgs.replaceVarsWith;
    };
  paths = {
    lockFileAbs =
      config.paths.projectRoot + "/${config.paths.package}/${config.paths.lockFile}";
    cacheFileAbs =
      config.paths.projectRoot + "/${config.paths.package}/${config.paths.cacheFile}";

    # - identify the root by searching for the marker config.paths.projectRootFile in the current dir and parents
    # - if the marker file is not found, raise an error
    findRoot = let
      program = config.deps.replaceVarsWith {
        replacements = {
          projectRootFile = config.paths.projectRootFile;
          python3 = config.deps.python3;
        };
        isExecutable = true;
        src = ./find-root.py;
      };
    in "${program}";
  };
}
