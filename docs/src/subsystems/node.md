# Node.js subsystem

This section documents the Node.js subsystem.

## Example

> ./flake.nix

```nix
{{#include ../../../examples/nodejs_eslint/flake.nix}}
```

> ./projects.toml

```toml
{{#include ../../../examples/nodejs_eslint/projects.toml}}
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

### strict (pure + best compatibility) (experimental)

Works almost the same as the granular builder. Not bulletproof stable yet.
Recommended: Try it out, it should work better than the current default builder, but is not yet released as default.

Features 🌈

- Fully npm compatible
- No Patches / Overrides required (if "installMethod = copy")
  - (Most) Complex building of node_modules is fully implemented as python application, because it requires a lot of control flow.
  - Multiple outputs `["out" "lib" "deps"]` (explained below)
- Dedicated flattening of node_modules:
  - Conflicts are resolved during flattening the node_modules folder in favor of the highest semver)
  - Creates node_modules tree directly from package-lock.json informations. (Through the translator)
  - Creates node_modules tree with other lock files (such as yarn-lock) most optimal.
- consume itself:
  - lets you override/inject a package into your dream2nix project which is built with dream2nix

#### Usage

in `projects.toml` set the `builder` attribute to `'strict-builder'`

> ./projects.toml

```toml
{{#include ../../../examples/nodejs_alternative_builder/projects.toml}}
```

#### Override on the `strict-builder` (e.g custom bundling / static pages)

As currently the builder has three outputs: `$out`, `$lib`, `$deps`.

Sometimes it may be necessary to override the installPhase to build e.g. static page with `webpack` or others like `react`, `vue`, `anuglar` etc.

When overriding the `installPhase` the user is required to create all three out-paths:

> next.js export (e.g. for static sites)

```nix
installPhase = ''
    runHook preInstall

    next export
    cp -r out $out

    touch $deps
    touch $lib
    
    runHook postInstall
'';
}
```

#### Multiple outputs

##### deps

- content of `node_modules`
- consumable by `devShells`
- empty if package has no dependencies

```bash
    $deps
    /nix/store/...-pname-1.0.0-deps
    ├── .bin
    ├── @babel
    ├── ...
    └── typescript
```

##### package

- consumable as bare package
- containing all files from the `source` ( _install-scripts_ already executed )

```bash
    $lib
    /nix/store/...-pname-1.0.0-lib
    ├── cli.js
    ├── ...
    └── package.json
```

_install-scripts_ run in the following order:

> preinstall ->  install -> postinstall
>
> isolated from other packages
>
> if the isolation during installScript is causing you problems, let us know.

##### standard composition

- consumable by most users
- `{pname}/bin/...` contains all executables of this package

```bash
    $out:
    /nix/store/...-pname-1.0.0
    ├── bin
    │   └── cli -> ../lib/cli.js
    └── lib
        ├── cli.js 
        ├── ...
        ├── package.json 
        └── node_modules 
```
