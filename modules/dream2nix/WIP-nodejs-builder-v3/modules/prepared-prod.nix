{
  dream2nix,
  # _module.args
  plent,
  packageName,
  fileSystem,
  nodejs,
  ...
}: let
  makeNodeModules = ../scripts/build-node-modules.mjs;
in {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
  ];

  inherit (plent) version;
  name = packageName + "-node_modules-prod";
  env = {
    FILESYSTEM = builtins.toJSON fileSystem;
  };
  mkDerivation = {
    dontUnpack = true;
    buildInputs = [nodejs];
    buildPhase = ''
      node ${makeNodeModules}
    '';
  };
}
