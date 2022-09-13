# PHP subsystem

> !!! PHP support is experimental. \
> !!! You can track the progress in
> [nix-community/dream2nix#240](https://github.com/nix-community/dream2nix/issues/240).

This section documents the PHP subsystem.

## Example

An example of building [composer](https://github.com/composer/composer) using dream2nix.

```nix
{{#include ../../../examples/php_composer/flake.nix}}
```

## Translators

### composer-lock (pure)

Translates `composer.lock` into a dream2nix lockfile.

### composer-json (impure)

Resolves dependencies in `composer.json` using `composer` to generate a
`composer.lock` lockfile, then invokes the `composer-lock` translator to
generate a dream2nix lockfile.

## Builders

### simple (pure) (default)

Builds the package including all its dependencies in a single derivation.
