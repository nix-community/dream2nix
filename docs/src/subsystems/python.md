# Python subsystem

This section documents the Python subsystem.

## Examples
flake.nix
```nix
{{#include ../../../examples/python_pip_xxx/flake.nix}}
```
## Translators

### pip (impure)

Can translate all pip compatible python projects, including projects managed with poetry or other tool-chains which integrate via `pyproject.toml`.

This translator simply executes `pip download` on the given source and observes which sources are downloaded by pip.
The downside of this approach is, that this translator cannot be used with a granular builder. It does not understand the exact relation between the dependencies, and therefore it only allows to build all dependencies in one large derivation.

#### **pip** optional translator arguments
```nix
{{#include ../../../src/subsystems/python/translators/pip/args.nix}}
```

## Builders

### simple-builder (pure) (default)

Builds a package including all its dependencies in a single derivation.
