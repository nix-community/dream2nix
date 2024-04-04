# Consume and modify dream2nix packages

## Given the following package
`upstream/my-package.nix`
```nix
{config, lib, dream2nix, ...}: {

  imports = [
    dream2nix.modules.nodejs.mkDerivation
    dream2nix.modules.nodejs.package-lock
  ];

  pname = "my-package";
  version = "2.0.0";

  src = {
    type = github;
    owner = "my-user";
    repo = "my-repo";
    ref = config.version;
    hash = "sha256-mia90VYv/YTdWNhKpvwvFW9RfbXZJSWhJ+yva6EnLE8=";
  };

  # declare dependency on python3
  deps = {nixpkgs, ...}: {
    python3 = nixpkgs.python39;
  };

  nativeBuildInputs = [
    config.deps.python3
  ];

  configurePhase = ''
    python3 --version
  '';

  buildPhase = ''
    python3 -c 'print("Hello World!")' > $out
  '';
}
```

`upstream/default.nix`
```nix
{
  nixpkgs ? import <nixpkgs> {},
  dream2nix ?
    import
    (builtins.fetchTarball "https://dream2nix.dev/tarball/1.0")
    {inherit nixpkgs;},
}: {
  packages.my-package = dream2nix.eval ./my-package.nix;
}
```

## 1. Override using modules

### 1.1 Define a module for the override
`my-package-override.nix`
```nix
{config, lib, ... }: {

  version = "2.1.0";

  # No need to re-define other fetcher attributes.
  # The module system updates them for us.
  src.hash = "sha256-LM5GDNjLcmgZVQEeANWAOO09KppwGaYEzJBjYmuSwys=";

  deps = {nixpkgs, ...}: {

    # change the python version
    python3 = lib.mkForce nixpkgs.python310;

    # add a dependency on hello  
    hello = nixpkgs.hello;
  };

  # add hello to nativeBuildInputs
  # (`oldAttrs.nativeBuildInputs + ...` not needed here)
  nativeBuildInputs = [
    config.deps.hello
  ];

  # add lines to configurePhase
  postConfigure = ''
    hello --version
  '';

  # replace the build phase via mkForce
  buildPhase = lib.mkForce "
    hello > $out
  ";
}
```

### 1.2 Apply `my-package-override.nix` via extendModules
Using `extendModules` is simple.
It allows to extend an existing package with another module.
This doesn't require knowledge about the original modules that went into the package.

`./default.nix`
```nix
let
  nixpkgs = import <nixpkgs> {};
  upstream = import ./upstream {inherit nixpkgs;};
  my-package = upstream.packages.my-package;

  # The recommended way of modifying a package is using extendModules,
  #    which uses the module systems merge logic to apply changes.
  my-package-extended = my-package.extendModules {
    modules = [./my-package-override.nix];
  };

in {
  inherit my-package-extended;
}
```

### 1.3 Or apply `my-package-override.nix` via dream2nix.eval
This approach is a bit cleaner.
It doesn't introduce a chain of extendModules function calls.
This style also makes it obvious which modules went into the package.
Though, this requires access to the original `my-package.nix` module and knowledge about the `packageSets` that went into it.

`default.nix`
```nix
{
  nixpkgs ? import <nixpkgs> {},
  dream2nix ?
    import
    (builtins.fetchTarball "https://dream2nix.dev/tarball/1.0")
    {inherit nixpkgs;},

}: let

  my-package-extended = dream2nix.eval
    {packagetSets = {inherit nixpkgs;};}
    [
      ./upstream/my-package.nix
      ./my-package-override.nix
    ];

in {
  my-package-extended
}
```


## 2. Override package via `override[Attrs]` functions

It is recommended to use modules for overriding, like described above, but for backward compatibility, `overrideAttrs` and `override` are still supported.

```nix
let
  nixpkgs = import <nixpkgs> {};
  upstream = import ./upstream {inherit nixpkgs;};
  my-package = upstream.packages.my-package;

  # Override the package via `override` and `overrideAttrs`
  my-package-overridden' = my-package.override
    (oldAttrs: {

      # change the python version
      python3 = nixpkgs.python310;
    });

  my-package-overridden = my-package-overridden'.overrideAttrs
    (oldAttrs: rec {

      version = "2.1.0";

      src = nixpkgs.fetchFromGithub {
        owner = "my-owner";
        repo = "my-repo";
        ref = version;
        hash = "sha256-LM5GDNjLcmgZVQEeANWAOO09KppwGaYEzJBjYmuSwys=";
      };

      # add hello to nativeBuildInputs
      nativeBuildInputs = [
        nixpkgs.hello
      ];

      # add lines to configurePhase
      postConfigure = ''
        hello --version
      '';

      # replace the build phase
      buildPhase = ''
        hello > $out
      '';
    });

in {
  inherit my-package-overridden;
}
```
