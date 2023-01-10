# initialize nodejs project + dev shell

## load shell with nodejs + npm
```console tesh-session="next-app" tesh-setup="setup.sh"
$ nix-shell -p https://dream2nix.dev -A devShells.nodejs
```

## create my-app
```console tesh-session="next-app"
npx create-next-app my-app
```
This creates `./my-app/package.json` and more, using `create-next-app` as a helper.

## create `my-app.nix`
`my-app.nix`
```nix
{config, lib, dream2nix, ...}: {

  imports = [
    # default module to create a nodejs package
    dream2nix.modules.nodejs.mkDerivation
    # get package dependencies from package-lock
    dream2nix.modules.nodejs.package-lock
  ];

  # Allows to manipulate dependency builds
  overrides.local.path = ./overrides;

  src = ./my-app;

  # add more mkDerivation attributes here to customize...
}
```

## create `my-app-shell.nix` for your dev shell
`my-app-shell.nix`
```nix
{config, lib, dream2nix, ...}: {

  imports = [
    # the default dev shell for nodejs
    dream2nix.modules.nodejs.mkShell
    # adds dependencies of my-app to the dev shell
    dream2nix.modules.nodejs.package-lock
  ];

  src = ./my-app;

  # include hello from nixpkgs.
  # `deps` is the single source of truth for inputs from the `outside world`.
  # `deps` will later allow us to safely override any dependency.
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) hello;
  };

  # add hello from nixpkgs to the dev shell
  buildInputs = [
    config.deps.hello
  ]
}
```

## create `default.nix` entry point
`default.nix`
```nix
{
  nixpkgs ? import <nixpkgs> {},
  dream2nix ?
    import
    (builtins.fetchTarball "https://dream2nix.dev/tarball/1.0")
    {inherit nixpkgs;},
}: {
  packages.my-app = dream2nix.eval ./my-app.nix;
  devShells.my-app = dream2nix.eval ./my-app-shell.nix;
}
```

## build my-app
```command
nix-build -f ./default.nix -A packages.my-app
```
## create `shell.nix` (used by `nix-shell` command)
`shell.nix`
```nix
(import ./default.nix {}).devShells.my-app
```
Enter the dev shell:
```command
nix-shell
```
all dependencies of my-app are available

## fix build of dependencies via `./overrides/`
Files in `./overrides/` must always be named like the package they apply to.

Example: `./overrides/keytar.nix`
##
```nix
{config, ...}: {

  # include dependencies from nixpkgs.
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) 
      libsecret
      pkg-config
      ;
  };

  # add build time dependencies
  nativeBuildInputs = [
    config.deps.libsecret
    config.deps.pkg-config
  ];
}
```

Scoped package example: `./overrides/@babel/core.nix`
##
```nix
{config, ...}: {
  # ...
}
```
