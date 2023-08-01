# Why Modules?

Declaring derivations as modules solves a number of issues.
For more details on the problems, visit [DavHau/pkgs-modules](https://github.com/DavHau/pkgs-modules).
Also I recommend watching @edolstra 's [talk about this topic](https://www.youtube.com/watch?v=dTd499Y31ig).

# Benefits

## Deprecate override functions

Changing options of packages in nixpkgs can require chaining different override functions like this:

```nix
{
  htop-mod = let
    htop-overridden = pkgs.htop.overrideAttrs (old: {
      pname = "htop-mod";
    });
  in
    htop-overridden.override (old: {
      sensorsSupport = false;
    });
}
```

... while doing the same using `dream2nix` looks like this:

```nix
{
  htop-mod = {
    imports = [./htop.nix];
    name = lib.mkForce "htop-mod";
    flags.sensorsSupport = false;
  };
}
```

See htop module definition [here](https://github.com/nix-community/dream2nix/blob/main/examples/dream2nix-packages-simple/htop-with-flags/default.nix).

## Type safety

The following code in nixpkgs mkDerivation mysteriously skips the patches:

```nix
mkDerivation {
  # ...
  dontPatch = "false";
}
```

... while doing the same using `dream2nix` raises an informative type error:

```
A definition for option `[...].dontPatch' is not of type `boolean' [...]
```

## Catch typos

The following code in nixpkgs mkDerivation builds **without** openssl_3.

```nix
mkDerivation {
  # ...
  nativBuildInputs = [openssl_3];
}
```

... while doing the same using `dream2nix` raises an informative error:

```
The option `[...].nativBuildInputs' does not exist
```

## Environment variables clearly defined

`dream2nix` requires a clear distinction between known parameters and user-defined variables.
Defining `SOME_VARIABLE` at the top-level, would raise:

```
The option `[...].SOME_VARIABLE' does not exist
```

Instead it has to be defined under `env.`:

```nix
{
  my-package = {
    # ...
    env.SOME_VARIABLE = "example";
  };
}
```

## Documentaiton / Discoverability

No more digging the source code to find possible options to override.

Documentation similar to [search.nixos.org](https://search.nixos.org) can be generated for packages declared via `dream2nix`.

Every package built with `dream2nix` has a `.docs` attribute that builds an html documentation describing it's options.

## Package blueprints

With `dream2nix`, packages don't need to be fully declared. Options can be left without defaults, requiring the consumer to complete the definition.

For example, this can be useful for lang2nix tools, where `src` and `version` are dynamically provided by a lock file parser.

## Flexibility

The nixos module system gives maintainers more freedom over how packages are split into modules. Separation of concerns can be implemented more easily.
For example, the dependency tree of a package set can be factored out into a separate module, allowing for simpler modification.
