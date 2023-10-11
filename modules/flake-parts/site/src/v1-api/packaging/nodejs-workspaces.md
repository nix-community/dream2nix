# build + develop on nodejs workspaces
## assuming a `package.json` with workspaces
`package.json`
```
{
  "name": "my-workspaces",
  "workspaces": [
    "my-tool"
    "my-first-app"
    "my-second-app"
  ]
}
```

## define package set via `workspaces.nix`
```nix
{config, lib, dream2nix, ...}: {

  imports = [
    dream2nix.modules.nodejs.workspaces
    dream2nix.modules.nodejs.package-lock
  ];

  src = ./.;

  # Allows to manipulate builds of workspace members and their dependencies
  overrides.local.path = ./overrides;
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
  packages = {
    inherit (dream2nix.lib.mkPackageSet ./workspaces.nix)
      my-tool
      my-first-app
      my-second-app
      ;
  };
}
```

## configure package builds via `./overrides/`
Files in `./overrides/` must always be named like the the package they apply to.

Manipulate my-tool via `./overrides/my-tool.nix`
```nix
{config, ...}: {

  # include python from nixpkgs
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) python;
  };

  buildInputs = [
    config.deps.python
  ];
}
```

Manipulate my-first-app via `./overrides/my-first-app.nix`
```nix
{config, ...}: {

  # include my-tool from the local workspace
  deps = {workspace, ...}: {
    inherit (workspace) my-tool;
  };

  buildInputs = [
    config.deps.my-tool
  ];
}
```
