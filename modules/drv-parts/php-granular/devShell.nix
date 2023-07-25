{
  name,
  pkg,
  mkShell,
  php,
  composer,
}:
mkShell {
  buildInputs = [
    php
    composer
  ];
  shellHook = let
    vendorDir =
      pkg.overrideAttrs
      (_: {
        dontInstall = true;
      })
      + "/lib/vendor/${name}/vendor";
  in ''
    rm -rf ./vendor
    mkdir vendor
    cp -r ${vendorDir}/* vendor/
    chmod -R +w ./vendor
    export PATH="$PATH:$(realpath ./vendor)/bin"
  '';
}
