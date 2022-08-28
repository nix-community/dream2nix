# PHP subsystem

> !!! PHP support is a work in progress, and it is not yet usable (a
> builder is missing). You can track the progress in
> [nix-community/dream2nix#240](https://github.com/nix-community/dream2nix/issues/240).

This section documents the PHP subsystem.

## Translators

### composer-lock (pure)

Translates `composer.lock` into a dream2nix lockfile.

### composer-json (impure)

Resolves dependencies in `composer.json` using `composer` to generate a
`composer.lock` lockfile, then invokes the `composer-lock` translator to
generate a dream2nix lockfile.

## Builders

None so far.
