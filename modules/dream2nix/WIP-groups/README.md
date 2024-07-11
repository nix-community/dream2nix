---
title: "groups"
state: internal
maintainers:
  - DavHau
---

Module to deal with package sets (so called groups in dream2nix)

## Separate different kinds of dependencies

Many language specific package managers support declaration of different kinds of dependencies like, for example:
  - `dependencies`, `devDependencies` in nodejs
  - `dependencies`, `optional-dependencies.dev`, `optional-dependencies.test`, etc. in python

The dream2nix groups module allows to keep the upstream separation by splitting the dependency definitions into different attribute sets located at:
```
config.groups.<group>.packages.<name>.<version>
```

This separation is relevant because not all dependencies are needed for all targets.
A devShell for example requires the dev dependencies, while the runtime environment of the built package does not.

## Re-use package definitions

Each package definition in a group contains two important attributes:
- `[...].packages.<name>.<version>.module`: for the package definition
- `[...].packages.<name>.<version>.public`: for the final evaluated derivation

Having the package definition (`module`) separated from the result allows to re-use the definition elsewhere.
For example, a new group could be assembled by referring to the `modules` of existing groups:

```nix
{config, dream2nix, ...}: {

  # TODO: This is too complex. Defining a selector function should be enough to
  #   assemble new groups.
  # Any specifics about a package other than it's `ecosystem`, `name, `version
  #   are not important, as everything else is expressed via override modules.
  # Simply naming the keys of packages should be sufficient to assemble groups.

  # The dev group
  groups.dev = {

    # a hello package
    packages.hello."1.0.0".module = {
      imports = [
        dream2nix.modules.dream2nix.mkDerivation
      ];
      name = "hello";
      version = "1.0.0";
      mkDerivation.buildPhase = lib.mkForce ''echo "Hello World!" > $out''
    };

    # a modified hello package depending on the original hello definition
    packages.hello-mod."1.0.0".module = {
      imports = [
        # import the module definition of `hello` from above
        config.groups.dev.packages.hello.module
      ];
      mkDerivation.buildPhase = ''echo "Good Bye World!" > $out'';
    };
  };

  # The test group
  groups.test = {

    # a hello package based on `hello`` from the `dev` group
    packages.hello."1.0.0".module = {
      imports = [
        # import the module definition of `hello` from the `dev` group
        config.groups.dev.packages.hello.module
      ];
      mkDerivation.buildPhase = ''echo "Happy testing!" > $out''
    };
  }
}
```

## TODOs

- Expose all package candidates somehow (not grouped)
- Create groups by simply defining `selector` functions instead of referring to other group's packages modules.
