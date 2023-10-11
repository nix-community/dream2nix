{
  config,
  lib,
  ...
}: {
  imports = [
    ./interface.nix
    ../deps
  ];
  deps = {nixpkgs, ...}: {
    python3 = nixpkgs.python3;
    substituteAll = nixpkgs.substituteAll;
  };
  paths = {
    lockFileAbs =
      config.paths.projectRoot + "/${config.paths.package}/${config.paths.lockFile}";
    cacheFileAbs =
      config.paths.projectRoot + "/${config.paths.package}/${config.paths.cacheFile}";

    # - identify the root by searching for the marker config.paths.projectRootFile in the current dir and parents
    # - if the marker file is not found, raise an error
    findRoot = let
      program = config.deps.substituteAll {
        src = ./find-root.py;
        projectRootFile = config.paths.projectRootFile;
        python3 = config.deps.python3;
        postInstall = "chmod +x $out";
      };
    in "${program}";
  };
}
