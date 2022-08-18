# Node.js subsystem

This section documents the Node.js subsystem.

## Example

```nix
{{#include ../../../examples/nodejs_eslint/flake.nix}}
```

## Translators

### package-lock (pure)

Translates `package-lock.json` into a dream2nix lockfile.

### package-json (impure)

Resolves dependencies from `package.json` using `npm` to generate a
`package-lock.json`, then uses `package-lock` translator to generate the
dream2nix lockfile.

### yarn-lock (pure)

Translates `yarn.lock` into a dream2nix lockfile.

## Builders

### granular (pure) (default)

Builds all the dependencies in isolation, moving upwards to the top
package.
At the end copies over all dependencies into `node_modules` and writes
symlinks for the bins into `node_modules/.bin`.
