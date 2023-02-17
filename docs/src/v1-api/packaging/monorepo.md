# build packages in a monorepo
The example mono repo has 3 packages: `nodejs-app`, `python-tool`, `rust-tool`.

The packages `python-tool` and `rust-tool` might or might not be built with dream2nix.

The package `nodejs-app` is built with dream2nix and depends on `python-tool` and `rust-tool`.

## Assuming this repo structure
```
├── default.nix
├── overrides
│  ├── nodejs
│  ├── python
│  └── rust
├── nodejs-app
│  └── default.nix
├── python-tool
│  └── default.nix
└── rust-tool
   └── default.nix
```

## Contents of `./nodejs-app/default.nix`
`./nodejs-app/default.nix`
```nix
{config, lib, dream2nix, ...}: {

  imports = [
    # default module to create a nodejs package
    dream2nix.modules.nodejs.mkDerivation
    # get package dependencies from package-lock
    dream2nix.modules.nodejs.package-lock
  ];

  # Overrides allow to manipulate dependency builds
  overrides.local.path = ../overrides/nodejs;

  src = ./.;
  
  # include dependencies from nixpkgs and the local monorepo
  # see definition of `packageSets` in ../default.nix
  deps = {nixpkgs, monorepo, ...} @ packageSets: {
    inherit (nixpkgs)
      hello
      ;
    inherit (monorepo)
      python-tool
      rust-tool
      ;
  };

  nativeBuildInputs = [
    config.deps.hello
    config.deps.python-tool
    config.deps.rust-tool
  ];

  configurePhase = ''
    hello --version
    python-tool --version
    rust-tool --version
  '';

  # add more mkDerivation attributes here to customize...
}
```

## Contents of `./default.nix`
`./default.nix`
```nix
{
  nixpkgs ? import <nixpkgs> {},
  dream2nix ?
    import
    (builtins.fetchTarball "https://dream2nix.dev/tarball/1.0")
    {inherit nixpkgs;},

} @ inputs: let

  makePackage = modules: dream2ix.mkDerivation
    # Package sets available to each package's `deps` function
    {packageSets = {inherit monorepo nixpkgs;};}
    modules;

  monorepo = {
    nodejs-app = makePackage ./nodejs-app;
    python-tool = makePackage ./python-tool;
    rust-tool = makePackage ./rust-tool;
  };

in {
  packages = monorepo;
}
```
