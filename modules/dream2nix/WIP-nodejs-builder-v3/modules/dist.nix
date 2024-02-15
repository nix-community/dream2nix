{
  # default args
  # lib
  dream2nix,
  # _module.args
  packageName,
  plent,
  prepared-dev,
  packageLockFile,
  trustedDeps,
  nodejs,
  jq,
  ...
}: let
  installTrusted = ../scripts/install-trusted-modules.mjs;
in {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
  ];

  inherit (plent) version;
  name = packageName + "-dist";
  env = {
    TRUSTED = builtins.toJSON trustedDeps;
  };
  mkDerivation = {
    # inherit (entry) version;
    src = builtins.dirOf packageLockFile;
    buildInputs = [nodejs jq];
    configurePhase = ''
      cp -r ${prepared-dev}/node_modules node_modules
      chmod -R +w node_modules
      node ${installTrusted}
    '';
    buildPhase = ''
      echo "BUILDING... $name"

      if [ "$(jq -e '.scripts.build' ./package.json)" != "null" ]; then
        echo "BUILDING... $name"
        export HOME=.virt
        npm run build
      else
        echo "$(jq -e '.scripts.build' ./package.json)"
        echo "No build script";
      fi;
    '';
    installPhase = ''
      echo "Removing (dev)node_modules from dist output."
      rm -rf node_modules
      # TODO: filter files
      cp -r . $out
    '';
  };
}
