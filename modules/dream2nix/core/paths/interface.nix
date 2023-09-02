{
  lib,
  config,
  ...
}: {
  options.paths = lib.mapAttrs (_: lib.mkOption) {
    # mandatory fields
    projectRoot = {
      type = lib.types.path;
      description = ''
        Path to the root of the project on which dream2nix operates.
        Must contain the marker file specified by 'paths.projectRootFile'

        This helps locating lock files at evaluation time.
      '';
      example = lib.literalExpression "./.";
    };
    package = {
      type = lib.types.str;
      description = ''
        Path to the directory containing the definition of the current package.
        Relative to 'paths.projectRoot'.

        This helps locating package definitions for lock & update scripts.
      '';
    };

    # optional fields
    projectRootFile = {
      type = lib.types.str;
      description = ''
        File name to look for to determine the root of the project.
        Ensure 'paths.projectRoot' contains a file named like this.

        This helps locating package definitions for lock & update scripts.
      '';
      example = ".git";
      default = ".git";
    };
    lockFile = {
      type = lib.types.str;
      description = ''
        Path to the lock file of the current package.
        Relative to "''${paths.projectRoot}/''${paths.package}"".
      '';
      default = "lock.json";
    };
    cacheFile = {
      type = lib.types.str;
      description = ''
        Path to the eval cache file of the current package.
        Relative to "''${paths.projectRoot}/''${paths.package}"".
      '';
      default = "cache.json";
    };

    # internal fields
    lockFileAbs = {
      internal = true;
      type = lib.types.path;
      description = ''
        Absolute path to the lock file of the current package.
        Derived from 'paths.projectRoot', 'paths.package' and 'paths.lockFile'.
      '';
    };
    cacheFileAbs = {
      internal = true;
      type = lib.types.path;
      description = ''
        Absolute path to the eval cache file of the current package.
        Derived from 'paths.projectRoot', 'paths.package' and 'paths.cacheFile'.
      '';
    };
    findRoot = {
      internal = true;
      type = lib.types.str;
      description = ''
        Executable script to find the package definition of the current package.
      '';
    };
  };
}
