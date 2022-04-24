<p align="center">
<img width="400" src="https://gist.githubusercontent.com/DavHau/755fed3774e89c0b9b8953a0a25309fa/raw/e2a12a60ae49aa5eb11b42775abdd1652dbe63c0/dream2nix-01.png">
</p>

## [WIP] dream2nix - A framework for automated nix packaging

dream2nix is a framework for automatically converting packages from other build systems to nix.
It focuses on the following aspects:

- Modularity
- Customizability
- Maintainability
- Nixpkgs Compatibility (not enforcing IFD)
- Code de-duplication across 2nix converters
- Code de-duplication in nixpkgs
- Risk free opt-in FOD fetching (no reproducibility issues)
- Common UI across 2nix converters
- Reduce effort to develop new 2nix solutions
- Exploration and adoption of new nix features
- Simplified updating of packages

The goal of this project is to create a standardized, generic, modular framework for automated packaging solutions, aiming for better flexibility, maintainability and usability.

The intention is to integrate many existing 2nix converters into this framework, thereby improving many of the previously named aspects and providing a unified UX for all 2nix solutions.

### Test the experimental version of dream2nix
(Currently only nodejs and rust packaging is supported)

1. Make sure you use a nix version >= 2.4 and have `experimental-features = "nix-command flakes"` set.
1. Navigate to to the project indended to be packaged and initialize a dream2nix flake:
    ```command
      cd ./my-project
      nix flake init -t github:nix-community/dream2nix#simple
    ```
1. List the packages that can be built
    ```command
      nix flake show
    ```


Minimal Example `flake.nix`:
```nix
{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = { self, dream2nix }@inputs:
    let
      dream2nix = inputs.dream2nix.lib.init {
        # modify according to your supported systems
        systems = [ "x86_64-linux" ];
        config.projectRoot = ./. ;
      };
    in dream2nix.makeFlakeOutputs {
      source = ./.;
    };
}
```

Extensive Example `flake.nix`:
```nix
{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = { self, dream2nix }@inputs:
    let
      system = "x86_64-linux";

      pkgs = inputs.dream2nix.nixpkgs.legacyPackages.${system};

      dream2nix = inputs.dream2nix.lib.init {
        # modify according to your supported systems
        systems = [ system ];
        config.projectRoot = ./. ;
      };

    in dream2nix.makeFlakeOutputs {
      source = ./.;

      # Configure the behavior of dream2nix when translating projects.
      # A setting applies to all discovered projects if `filter` is unset,
      # or just to a subset or projects if `filter` is used.
      settings = [

        # prefer aggregated source fetching (large FODs)
        {
          aggregate = true;
        }

        # for all impure nodejs projects with just a `package.json`,
        # add arguments for the `package-json` translator
        {
          filter = project: project.translator == "package-json";
          subsystemInfo.npmArgs = "--legacy-peer-deps";
        }
      ];

      # configure package builds via overrides
      # (see docs for override system below)
      packageOverrides = {
        # name of the package
        package-name = {
          # name the override
          add-pre-build-steps = {
            # override attributes
            preBuild = "...";
            # update attributes
            buildInputs = old: old ++ [ pkgs.hello ];
          };
          # a more complicated override like esbuild in the repo
          "add-binary-0.13" = let 
            # some additional functions are available in utils
            # run `nix repl flake.nix` and `:lf .` to find out about
            # all of them
            utils = inputs.dream2nix.lib.x86_64-linux.utils;
            # in case you need to use nixpkgs
            pkgs = inputs.dream2nix.inputs.nixpkgs.legacyPackages.x86_64-linux;
            in {
            _condition = utils.satisfiesSemver "~0.13";
            # you can add environment variables if needed
            ESBUILD_BINARY_PATH = let
              esbuild = pkgs.buildGoModule rec {
                pname = "esbuild";
                version = "0.13.15";

                src = pkgs.fetchFromGitHub {
                  owner = "evanw";
                  repo = "esbuild";
                  rev = "v${version}";
                  sha256 = "sha256-Ffnz70UfHAu3p39oZkiwPF0tX++uYr/T4E7G4jVRUUE=";
                };

                vendorSha256 = "sha256-QPkBR+FscUc3jOvH7olcGUhM6OW4vxawmNJuRQxPuGs=";
              };
            in "${esbuild}/bin/esbuild";
            };
          };
        };
      };

      # Inject missing dependencies
      # Make foo depend on bar and baz
      inject = {
        # from
        foo."6.4.1" = [
          # to
          ["bar" "13.2.0"]
          ["baz" "1.0.0"]
        ];
      };

      # add sources for `bar` and `baz`
      sourceOverrides = {
        bar."13.2.0" = builtins.fetchTarball {url = ""; sha256 = "";};
        baz."1.0.0" = builtins.fetchTarball {url = ""; sha256 = "";};
      };
    };
}
```

### Watch the presentation
(The code examples of the presentation are outdated)
[![dream2nix - A generic framework for 2nix tools](https://gist.githubusercontent.com/DavHau/755fed3774e89c0b9b8953a0a25309fa/raw/3c8b2c56f5fca3bf5c343ffc179136eef39d4d6a/dream2nix-youtube-talk.png)](https://www.youtube.com/watch?v=jqCfHMvCsfQ)

### Further Reading

- [Summary of the core concepts and benefits](/docs/concepts-and-benefits.md)
- [How would this improve the packaging situation in nixpkgs](/docs/nixpkgs-improvements.md)
- [Override System](/docs/override-system.md)
- [Contributors Guide](/docs/contributors-guide.md)

### Community
matrix: https://matrix.to/#/#dream2nix:nixos.org

