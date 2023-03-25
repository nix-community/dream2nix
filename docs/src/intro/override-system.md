The override system plays an important role when packaging software with dream2nix. Overrides are the only way to express package specific logic in dream2nix. This serves the purpose of strictly separating:
```
  - generic logic     (builders)
  - specific logic    (overrides)
  - data              (dream-lock.json)
```

To optimize for scalable workflows, the structure of dream2nix overrides differs from the ones seen in other projects.
dream2nix overrides have the following properties:
  - **referenceable**: each override is assigned to a key through which it can be referenced. This allows for better inspection, selective debugging, replacing, etc.
  - **conditional**: each override can declare a condition, so that the override only applies when the condition evaluates positively.
  - **attribute-oriented**: The relevant parameters are attributes, not override functions. dream2nix will automatically figure out which underlying function (eg. override, overrideAttrs, ...) needs to be called to update each given attribute. The user is not confronted with this by default.

Each subsystem in dream2nix like `nodejs` or `python` manages its overrides in a separate directory to avoid package name collisions.

dream2nix supports packaging different versions of the same package within one repository. Therefore conditions are used to make overrides apply only to certain package versions.

Currently a collection of overrides is maintained at [dream2nix/overrides](https://github.com/nix-community/dream2nix/tree/main/overrides)

## General override system

values can either be declared directly via

```nix
# "${pname}" = {
#   "${overrideName}" = {
#     ...
#     `attrName` will get overriden with `newValue`
#     ${attrName} = newValue;  
#     ...
#   };
# };
#
```

or via function that takes the `oldAttrs` and returns `newAttrs` depending on the old ones.

```nix
#  
# "${pname}" = {
#   "${overrideName}" = {
#     ...
#     overrideAttrs = oldAttrs: {
#       ${attrName} = ...;
#     };
#     ...
#   };
# };
```

## Overview of `attrNames`

The available values depend on the subsystem
But at least all values of `pkgs.mkDerivation` are available on every subsystem

```nix

# some internal attributes
# if that attribute is true the override will apply
# e.g. _condition = satisfiesSemver "^5.0.0";
_condition


# attributes of the nodejs subsystem 
dependenciesJson
electronHeaders
nodeDeps
nodeSources
packageName
installMethod
electronAppDir
runBuild
linkBins
installDeps
buildScript

# python script to modify some metadata to support installation
# (see comments below on d2nPatch)
fixPackage

# attibutes of mkDerivation (also found in the nix manual)
nativeBuildInputs
buildInputs
src
configurePhase 
buildPhase 
installPhase 
patches
...

```

# Example for nodejs overrides

```nix
{
  # The name of a package.
  # Contains all overrides which can apply to the package `enhanced-resolve`
  enhanced-resolve = {

    # first override for enhanced-resolve named `preserve-symlinks-v4`
    preserve-symlinks-v4 = {

      # override will apply for packages with major version 4
      _condition = satisfiesSemver "^4.0.0";

      # this statement replaces exisiting patches
      # (for appending see next example)
      patches = [
        ./enhanced-resolve/npm-preserve-symlinks-v4.patch
      ];

    };

    # second override for enhanced-resolve
    preserve-symlinks-v5 = {

      # override will apply for packages with major version 5
      _condition = satisfiesSemver "^5.0.0";

      # this statement adds a patch to the exsiting list of patches
      patches = old: old ++ [
        ./enhanced-resolve/npm-preserve-symlinks-v5.patch
      ];
    };

  };

  # another package name
  webpack = {
    # overrides for webpack
  };
}
```

# Example for PHP flake override

This example overrides `prePatch` for the `ml/iri` package to drop the
unsupported `target-dir` attribute from composer.json:

```
{
  inputs.dream2nix.url = "github:nix-community/dream2nix";

  outputs = inp:
    inp.dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      source = ./.;
      projects = ./projects.toml;
      packageOverrides = {
        "^ml.iri.*".updated.overrideAttrs = old: {
          prePatch = ''
            cat composer.json | grep -v target-dir | sponge composer.json
          '';
        };
      };
    };
}
```
