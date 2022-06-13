# Rust subsystem

This section documents the Rust subsystem.

## Translators

### cargo-lock (pure)

Translates a `Cargo.lock` file to a dream2nix lockfile.

### cargo-toml (impure)

Translates a `Cargo.toml` file to a dream2nix lockfile by generating a
`Cargo.lock` file first and then using `cargo-lock` translator on the
generated lockfile.

## Builders

### build-rust-package (pure)

Builds a package using `buildRustPackage` from `nixpkgs`.

### crane (ifd)

Builds a package using [`crane`](https://github.com/ipetkov/crane).

#### Override gotchas

This builder builds two separate derivations, one for your crate's dependencies
and another for your crate. This means that if you want to override stuff for
the dependencies, you need to use the `<crate-name>-deps` key for your override
where `<crate-name>` is the name of the crate you are building.
