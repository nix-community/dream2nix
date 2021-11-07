The override system plays an important role when packaging software with drem2nix. Overrides are the only way to express package specific logic in dream2nix. This serves the purpose of strictly separating:
```
  - generic logic     (builders)
  - specific logic    (overrides)
  - data              (dream-lock.json)
```

To optimize for scalalable workflows, the structure of dream2nix overrides differs from the ones seen in other projects.
dream2nix overrides have the following properties:
  - **referenceable**: each override is assigned to a key through which it can be referenced. This allows for better inspection, selective debugging, replacing, etc.
  - **conditional**: each override can declare a condition, so that the override only applies when the condiiton evaluates positively.
  - **attribute-oriented**: The relevant parameters are attributes, not override functions. dream2nix will automatically figure out which underlying function (eg. override, overrideAttrs, ...) needs to be called to update each given attribute. The user is not confronted with this by default.

Each subsytem in dream2nix like `nodejs` or `python` manages its overrides in a separate directory to avoid package name collisions.

dream2nix supports packaging different versions of the same package within one repository. Therefore conditions are used to make overrides apply only to certain package versions.

Currently a collection of overrides is maintained at https://github.com/DavHau/dreampkgs

Example for nodejs overrides:
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