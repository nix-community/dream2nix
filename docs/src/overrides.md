# Overriding Dependencies in Dream2nix

Dream2nix automates the generation of build instructions for packages, including their dependencies. Occasionally, these instructions may require manual adjustments, called overrides, in situations where:

- A package fails to build.
- A package does not function as expected.
- A package needs to be compiled with specific features.

There are three primary methods to override dependencies in dream2nix:

- **Global Overrides**: Configured via `overrideAll`, affecting all dependencies of the current package.
- **Local Overrides**: Configured via `overrides.${name}`, targeting dependencies with a specific name.
- **Community Overrides**: Predefined in dream2nix, applied automatically to relevant dependencies.

## Global Overrides

Global overrides apply universally to all dependencies within a specific language module in dream2nix. For instance, the Python `pip` module provides a `pip.overrideAll` option. This is particularly useful for modifying global defaults across all dependencies managed by the module.

### Global Overrides Example

By default, the `pip` module disables testing for dependencies. To enable testing globally, use `overrideAll` as shown below:

```nix
{config, lib, ...}: {
  pip.overrideAll.mkDerivation.doCheck = true;
}
```

## Local Overrides

Local overrides are specific to individual packages. This method allows for precise control over the build instructions for certain packages.

### Local Overrides Example

The following override applies exclusively to the `opencv-python` package, ensuring specific build dependencies are included:

```nix
{config, lib, ...}: {
  pip.overrides.opencv-python = {
    env.autoPatchelfIgnoreMissingDeps = true;
    mkDerivation.buildInputs = [
      pkgs.libglvnd
      pkgs.glib
    ];
  };
}
```

Note: For ecosystems like Node.js that may include multiple versions of a dependency, local overrides affect all versions by default. For version-specific overrides, refer to the [Conditionals](#conditionals) section.

## Community Overrides

Community overrides are akin to local overrides but are provided with dream2nix, applying automatically to their respective dependencies. They represent collective knowledge and fixes for common issues contributed by the user community.

### Contributing to Community Overrides

To contribute your overrides to the community, add them to the dream2nix source tree under `/overrides/{language}/{dependency-name}/default.nix`. Each dependency within an ecosystem should have its own override file. This structure ensures automatic application of these overrides during dependency resolution.

## Conditionals

Conditional overrides offer flexibility by allowing overrides to be applied based on specific criteria, such as dependency versions or feature flags.

### Conditionals Example

The following conditional override disables tests for versions of the `pillow` package version `10.0.0` or higher:

```nix
{config, lib, ...}: {
  pip.overrides.pillow = {
    mkDerivation.doCheck =
      if lib.versionAtLeast "10.0.0" config.version
      then false
      else true;
  };
}
```

## List of Options

Different dream2nix modules offer different options to override.
Refer to the [documentation](https://nix-community.github.io/dream2nix) of the specific language module to see the options.
Alternatively enter `{module-name}.overrides` into the documentation search.
