/*
devShell allowing for good interop with npm

The shellHook always overwrites existing ./node_modules with a full
flat copy of all transitive dependencies produced by dream2nix from
the lock file.

This allows good interop with npm. npm is still needed to update or
add dependencies. npm can write to the ./node_modules without
any issues and add or replace dependencies.

If npm modifies ./node_modules, then its contents will be a mix of
dream2nix installed packages and npm installed packages until the
devShell is re-entered and dream2nix overwrites the ./node_modules
with a fully reproducible copy again.
*/
{
  mkShell,
  nodejs,
  packageName,
  pkg,
}:
mkShell {
  buildInputs = [
    nodejs
  ];
  shellHook = let
    /*
    This uses the existig package derivation, and modifies it, to
    disable all phases but the one which creates the ./node_modules.

    The result is a derivation only generating the node_modules and
    .bin directories.

    TODO: This is be a bit hacky and could be abstracted better
    TODO: Don't always delete all of ./node_modules. Only overwrite
          missing or changed modules.
    */
    nodeModulesDrv = pkg.overrideAttrs (old: {
      installMethod = "copy";
      dontPatch = true;
      dontBuild = true;
      dontInstall = true;
      dontFixup = true;

      # the configurePhase fails if these variables are not set
      d2nPatchPhase = ''
        nodeModules=$out/lib/node_modules
        mkdir -p $nodeModules/$packageName
        cd $nodeModules/$packageName
      '';
    });
    nodeModulesDir = "${nodeModulesDrv}/lib/node_modules/${packageName}/node_modules";
    binDir = "${nodeModulesDrv}/lib/node_modules/.bin";
  in ''
    # create the ./node_modules directory
    rm -rf ./node_modules
    mkdir -p ./node_modules/.bin
    cp -r ${nodeModulesDir}/* ./node_modules/
    for link in $(ls ${binDir}); do
      target=$(readlink ${binDir}/$link | cut -d'/' -f4-)
      ln -s ../$target ./node_modules/.bin/$link
    done
    chmod -R +w ./node_modules
    export PATH="$PATH:$(realpath ./node_modules)/.bin"
  '';
}
