# Pex

Build python projects from [pex](https://pex.readthedocs.io/) lock files.

## What?

This module builds on `pex lock create` to create a universal lock file,
containing wheels and sdists for multiple platforms and all extras
declared in the given *requirements* - pythons traditional name for
dependencies.

It then uses [pyproject.nix](https://github.com/adisbladis/pyproject.nix) and
some custom glue to get the effective, platform-specific dependencies at
evaluation time.

## Why?

This approach has 2 main benefits compared to the existing `fetchPipMetadata`
module, where we write platform-specific lock files:

* Lock files stay platform-independent,. Its hard to impossible to generate
  correct platform-specific lock files for macOS on a Linux system with
  `fetchPipMetadata`. This makes it difficult to keep all platforms in sync
  without access to remote builders for each platform.
* We specify *requirements* with all *extras**, e.g. ``datasette[test,docs]` at
  lock time and device which *extras* to actually build during evaluation time.
  We have implemented this feature ourselves in a hacky way in
  `fetchPipMetadata`, but use pyproject.nix here to check which extras to build
  during evaluation time - but still without *IFD*.
  This feature could be back-ported to `fetchPipMetadata` but due to pip's
  lacking support for cross-platform lock files this is considered low priority.
  We first want to explore whether `pex` can cover all use cases and meanwhile
  keep track of [upstream work](https://github.com/pypa/pip/issues/11664).

## Why not (yet)?

* [ ] doesn't respect requires-python yet.
* [ ] add pex builds to other Python examples, there's not a single fully working one atm
* [ ] In previous attempt we had started from an idea of a python "project" or "package",
  while not considering the many obvious and some not-so-obvious differences between
  a *library*, an *application* and an *environment* here.
  We should probably work with nixpkgs notion of a python *module* here, while still
  considering the need for composable *devShells* and *editable installs* which mighti
  influence the design.
  tl;dr: there's some api design and documentation work here
* [ ] port selectWheels to pyproject. We currently vendor pep425.nix from
  poetry2nix for the ``selectWheel` function. That function should be
  re-implemented in terms of pyproject.nix primitives.`
* [ ] `datasette``as a first example is an interesting challenge as it includes
  `pip` as a dependency. That's a bit special and also currently fails to build for me.
* [ ] pex does not [include build-system.requires](https://github.com/pantsbuild/pex/issues/2100)
   in its lock files. This means that we would need to add them manually to
  `packages.$name.mkDerviation.nativeBuildInputs` for everything not
  already included via hook.

## Future Work
* There's `pypaBuildHook` coming to master via python-updates, that uses pypa/build instead of pip
  to build wheels.
* Test cyclic dependencies. Add at least one integration test for something like naked, as in #583
