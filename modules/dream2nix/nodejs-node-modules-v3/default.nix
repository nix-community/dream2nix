{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.nodejs-package-lock-v3
    dream2nix.modules.dream2nix.nodejs-granular-v3
  ];

  mkDerivation = {
    dontUnpack = true;
    dontPatch = true;
    dontBuild = true;
    dontInstall = true;
    dontFixup = true;
    preBuildPhases = l.mkForce [];
    preInstallPhases = l.mkForce ["installPhaseNodejsNodeModules"];
  };

  env = {
    # Prepare node_modules installation to $out/lib/node_modules
    patchPhaseNodejs = l.mkForce ''
      nodeModules=$out/lib/node_modules
      mkdir -p $nodeModules/$packageName
      cd $nodeModules/$packageName
    '';

    # copy .bin entries
    #   from $out/lib/node_modules/.bin
    #   to   $out/lib/node_modules/<package-name>/node_modules/.bin
    installPhaseNodejsNodeModules = ''
      mkdir -p ./node_modules/.bin
      localNodeModules=$nodeModules/$packageName/node_modules
      for executablePath in $out/lib/node_modules/.bin/*; do
        binaryName=$(basename $executablePath)
        target=$(realpath --relative-to=$localNodeModules/.bin $executablePath)
        echo linking binary $binaryName to nix store: $target
        ln -s $target $localNodeModules/.bin/$binaryName
      done
    '';
  };

  nodejs-granular-v3 = {
    installMethod = "copy";
  };
}
