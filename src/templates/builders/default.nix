{
  lib,
  pkgs,
  stdenv,
  # dream2nix inputs
  builders,
  externals,
  utils,
  ...
}: {
  # Funcs
  # AttrSet -> Bool) -> AttrSet -> [x]
  getCyclicDependencies, # name: version: -> [ {name=; version=; } ]
  getDependencies, # name: version: -> [ {name=; version=; } ]
  getSource, # name: version: -> store-path
  # to get information about the original source spec
  getSourceSpec, # name: version: -> {type="git"; url=""; hash="";}
  # Attributes
  subsystemAttrs, # attrset
  defaultPackageName, # string
  defaultPackageVersion, # string
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
} @ args: let
  b = builtins;

  # the main package
  defaultPackage = packages."${defaultPackageName}"."${defaultPackageVersion}";

  # manage packages in attrset to prevent duplicated evaluation
  packages =
    lib.mapAttrs
    (name: versions:
      lib.genAttrs
      versions
      (version: makeOnePackage name version))
    packageVersions;

  # Generates a derivation for a specific package name + version
  makeOnePackage = name: version: let
    pkg = stdenv.mkDerivation rec {
      pname = utils.sanitizeDerivationName name;
      inherit version;

      src = getSource name version;

      buildInputs =
        map
        (dep: packages."${dep.name}"."${dep.version}")
        (getDependencies name version);

      # Implement build phases
    };
  in
    # apply packageOverrides to current derivation
    (utils.applyOverridesToPackage packageOverrides pkg name);
in {
  inherit defaultPackage packages;
}
