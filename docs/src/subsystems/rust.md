# Rust subsystem

This section documents the Rust subsystem.

## Translators

### cargo-lock (pure)

Translates a `Cargo.lock` file to a dream2nix lockfile.

### cargo-toml (impure)

Translates a `Cargo.toml` file to a dream2nix lockfile by generating a `Cargo.lock` file first and then using `cargo-lock` translator on the generated lockfile.

## Builders

### build-rust-package (pure)

Builds a package using `buildRustPackage` from `nixpkgs`.

### crane (ifd) (default)

Builds a package using [`crane`](https://github.com/ipetkov/crane).
This builder builds two separate derivations, one for dependencies and the other for your crate.
The dependencies derivation will be named `<crate>-deps` where `<crate>` is the name of the crate you are building.

#### Setting profile and Cargo flags

This can be done via setting environment variables:

- `cargoTestFlags` and `cargoBuildFlags` are passed to `cargo` invocations for `checkPhase` and `buildPhase` respectively.
- `cargoTestProfile` and `cargoBuildProfile` are used as profiles while compiling for `checkPhase` and `buildPhase` respectively.

#### Override gotchas

This builder builds two separate derivations, one for your crate's dependencies and another for your crate.
This means that if you want to override stuff for the dependencies you need to use the `<crate-name>-deps` key for your override where `<crate-name>` is the name of the crate you are building.

```nix
{
  # ...
  packageOverrides = {
    # this will apply to your crate
    crate.my-overrides = { /* ... */ };
    # this will apply to your crate's dependencies
    crate-deps.my-overrides = { /* ... */ };
  };
  # ...
}
```

#### On the IFD marking

The `crane` builder utilizes IFD to clean the source your crates reside in.
This is needed to not rebuild the dependency only derivation everytime the source for your crates is changed.

However this does not mean that the IFD will always be triggered.
If you are passing dream2nix a path source or a flake source, then IFD won't be triggered as these sources are already realized.
But if you are passing the result of a `pkgs.fetchFromGitHub` for example, this will trigger IFD since it is not already realized.

### Specifying the Rust toolchain

Specify an override for all packages that override the Rust toolchain used.
This can be done like so:

```nix
{
  # ...
  packageOverrides = {
    # ...
    "^.*".set-toolchain.overrideRustToolchain = old: {
      inherit (pkgs) cargo rustc;
    };
    # ...
  };
  # ...
}
```

You can also of course override the toolchain for only certain crates:

```nix
{
  # ...
  packageOverrides = {
    # ...
    crate-name.set-toolchain.overrideRustToolchain = old: {
      inherit (pkgs) cargo rustc;
    };
    # ...
  };
  # ...
}
```

#### `crane` notes

The crane builder does not require a `rustc` package in the toolchain specified, only a `cargo` package is needed.
If cross-compiling, keep in mind that it also takes `cargo` packages like so:

```nix
{
  cargoHostTarget = cargo-package;
  cargoBuildBuild = other-cargo-package;
}
```

where `cargoHostTarget` has the same meaning as coming from a `pkgsHostTarget`.
And `cargoBuildBuild` has the same meaning as coming from a `pkgsBuildBuild`.

To override the toolchain for a specific package, you will need to set an override for both the dependencies and the main package derivation:

```nix
let
  toolchainOverride = old: { /* ... */ };
in
{
  # ...
  packageOverrides = {
    # ...
    crate-name.set-toolchain.overrideRustToolchain = toolchainOverride;
    crate-name-deps.set-toolchain.overrideRustToolchain = toolchainOverride;
    # ...
  };
  # ...
}
```

#### Examples

- Usage with [fenix](https://github.com/nix-community/fenix):
```nix
let
  # ...
  # we use the full toolchain derivation here as using
  # only the cargo / rustc derivation *does not* work.
  toolchain = fenix.packages.${system}.minimal.toolchain;
  # ...
in
{
  # ...
  packageOverrides = {
    # for crane builder
    "^.*".set-toolchain.overrideRustToolchain = old: {cargo = toolchain};
    # for build-rust-package builder
    "^.*".set-toolchain.overrideRustToolchain = old: {
      cargo = toolchain;
      rustc = toolchain;
    };
  };
  # ...
}
```

- Usage with [oxalica's rust-overlay](https://github.com/oxalica/rust-overlay):
```nix
let
  # ...
  toolchain = rust-overlay.packages.${system}.rust;
  # ...
in
{
  # ...
  packageOverrides = {
    # for crane builder
    "^.*".set-toolchain.overrideRustToolchain = old: {cargo = toolchain};
    # for build-rust-package builder
    "^.*".set-toolchain.overrideRustToolchain = old: {
      cargo = toolchain;
      rustc = toolchain;
    };
  };
  # ...
}
```

### Specifying the `stdenv`

`crane` supports specifying the `stdenv` like so:
```nix
{
  # ...
  packageOverrides = {
    # change all derivations' stdenv to clangStdenv
    "^.*".set-stdenv.override = old: {stdenv = pkgs.clangStdenv;};
  };
  # ...
}
```

`build-rust-package` builder does not support specifying the `stdenv`.
