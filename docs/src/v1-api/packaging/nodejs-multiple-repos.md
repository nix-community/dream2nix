# handle multiple repos
Assuming that `./repo1` and `./repo2` are separate git repositories.

Both repos have a single package `repo1/my-app` and `repo2/my-tool`.

In order to build `repo1/my-app` we need `repo2/my-tool` as a build time dependency.

The following structure is assumed:
```
├── repo1
│  ├── default.nix
│  └── my-app.nix
└── repo2
   ├── default.nix
   └── my-tool.nix
```

## contents of `repo1/my-app.nix`
`repo1/my-app.nix`
```nix
{config, lib, dream2nix, ...}: {

  imports = [
    dream2nix.modules.nodejs.mkDerivation
    dream2nix.modules.nodejs.package-lock
  ];

  src = ./.;

  # include my-tool from repo2
  deps = {repo2, ...}: {
    inherit (repo2) my-tool;
  };

  # add my-tool as build time dependency
  nativeBuildInputs = [
    config.deps.my-tool
  ];

  # use my-tool to build my-app
  buildPhase = ''
    my-tool build
    echo "done building"
  '';
}
```

## contents of `repo1/default.nix`
`repo1/default.nix`
```nix
{
  pkgs ? import <nixpkgs> {},
  dream2nix ?
    import
    (builtins.fetchTarball "https://dream2nix.dev/tarball/1.0")
    {inherit pkgs;},
}: {
  packages.my-app = dream2nix.eval
    {
      packageSets.nixpkgs = pkgs;
      
      # fetchGit could be used here alternatively
      packageSets.repo2 = import ../repo2/default.nix {};
    }
    ./my-app.nix;
}
```
