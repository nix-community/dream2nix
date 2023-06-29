{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;

  cfg = config.nodejs-devshell;
in {
  imports = [
    dream2nix.modules.drv-parts.mkDerivation
    dream2nix.modules.drv-parts.nodejs-package-lock
    dream2nix.modules.drv-parts.nodejs-granular
  ];

  mkDerivation = {
    dontUnpack = true;
    dontPatch = true;
    dontBuild = true;
    dontInstall = true;
    dontFixup = true;
    preBuildPhases = l.mkForce [];
    preInstallPhases = l.mkForce [];
  };

  env = {
    # Prepare node_modules installation to $out/lib/node_modules
    patchPhaseNodejs = l.mkForce ''
      nodeModules=$out/lib/node_modules
      mkdir -p $nodeModules/$packageName
      cd $nodeModules/$packageName
    '';
  };

  nodejs-granular = {
    installMethod = "copy";
  };
}
