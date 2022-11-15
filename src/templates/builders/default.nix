{
  pkgs,
  lib,
  ...
}: {
  type = "pure";

  build = {
    ### FUNCTIONS
    # AttrSet -> Bool) -> AttrSet -> [x]
    getCyclicDependencies, # name: version: -> [ {name=; version=; } ]
    getDependencies, # name: version: -> [ {name=; version=; } ]
    getSource, # name: version: -> store-path
    # to get information about the original source spec
    getSourceSpec, # name: version: -> {type="git"; url=""; hash="";}
    ### ATTRIBUTES
    subsystemAttrs, # attrset
    defaultPackageName, # string
    defaultPackageVersion, # string
    # all exported (top-level) package names and versions
    # attrset of pname -> version,
    packages,
    # all existing package names and versions
    # attrset of pname -> versions,
    # where versions is a list of version strings
    packageVersions,
    # function which applies overrides to a package
    # It must be applied by the builder to each individual derivation
    # Example:
    #   produceDerivation name (mkDerivation {...})
    produceDerivation,
    ...
  }: let
    l = lib // builtins;
    makeTopLevelPackage = pname: version: let
      deps = getDependencies pname version;
      depsSources = map ({
        name,
        version,
      }:
        getSource name version)
      deps;
    in
      pkgs.runCommand
      pname
      {}
      ''
        mkdir $out
        for dep in ${toString depsSources}; do
          cp -r $dep $out/$(basename $dep)
        done
      '';

    allPackages =
      l.mapAttrs
      (
        name: ver: {
          ${ver} = makeTopLevelPackage name ver;
        }
      )
      packages;
  in {
    packages = allPackages;
  };
}
