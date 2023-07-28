# Wraps config.deps.python.buildEnv in a drv-parts module, using drv-parts.package-func
{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.drv-parts.core
    dream2nix.modules.drv-parts.package-func
  ];

  options.deps.python = lib.mkOption {
    type = lib.types.package;
    description = "The python interpreter package to use";
  };

  options.buildPythonEnv = {
    extraLibs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = "Python packages to add to the environment";
      default = [];
    };
    extraOutputsToInstall = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };

    postBuild = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };

    ignoreCollisions = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    permitUserSite = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    makeWrapperArgs = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [];
    };
  };

  config = {
    package-func.func = config.deps.python.buildEnv.override;
    package-func.args = config.buildPythonEnv;
    package-func.outputs = ["out"] ++ config.buildPythonEnv.extraOutputsToInstall;

    deps = {nixpkgs, ...}: {
      python = l.mkOptionDefault nixpkgs.python3;
    };
  };
}
