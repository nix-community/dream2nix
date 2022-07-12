<p align="center">
<img width="400" src="https://gist.githubusercontent.com/DavHau/755fed3774e89c0b9b8953a0a25309fa/raw/e2a12a60ae49aa5eb11b42775abdd1652dbe63c0/dream2nix-01.png">
</p>

## [WIP] dream2nix - A framework for automated nix packaging

dream2nix is a framework for automatically converting packages from other build systems to nix.

It focuses on the following aspects:

- Modularity
- Customizability
- Maintainability
- Nixpkgs Compatibility, by not enforcing IFD (import from derivation)
- Code de-duplication across 2nix converters
- Code de-duplication in nixpkgs
- Risk-free opt-in aggregated fetching (larger [FODs](https://nixos.wiki/wiki/Glossary), less checksums)
- Common UI across 2nix converters
- Reduce effort to develop new 2nix solutions
- Exploration and adoption of new nix features
- Simplified updating of packages

The goal of this project is to create a standardized, generic, modular framework for automated packaging solutions, aiming for better flexibility, maintainability and usability.

The intention is to integrate many existing 2nix converters into this framework, thereby improving many of the previously named aspects and providing a unified UX for all 2nix solutions.

### Test the experimental version of dream2nix

(Currently only nodejs and rust packaging is supported)

1. Make sure you use a nix version >= 2.4 and have `experimental-features = "nix-command flakes"` set.
1. Navigate to to the project intended to be packaged and initialize a dream2nix flake:
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
  outputs = { self, dream2nix }:
    dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      source = ./.;
    };
}
```

Extensive Example `flake.nix`:
```nix
{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = { self, dream2nix }:
    dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;

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
          subsystemInfo.nodejs = 18;
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
            buildInputs = old: old ++ [pkgs.hello];
          };
        };
      };

      # Inject missing dependencies
      inject = {
        # Make foo depend on bar and baz
        # from
        foo."6.4.1" = [
          # to
          ["bar" "13.2.0"]
          ["baz" "1.0.0"]
        ];
        # dependencies with @ and slash require quoting
        # the format is the one that is in the lockfile
        "@tiptap/extension-code"."2.0.0-beta.26" = [
           ["@tiptap/core" "2.0.0-beta.174"]
         ];
      };

      # add sources for `bar` and `baz`
      sourceOverrides = oldSources: {
        bar."13.2.0" = builtins.fetchTarball {url = ""; sha256 = "";};
        baz."1.0.0" = builtins.fetchTarball {url = ""; sha256 = "";};
      };
    };
}
```

An example for instancing dream2nix per pkgs and using it to create outputs can be found at [`examples/d2n-init-pkgs`](./examples/d2n-init-pkgs/flake.nix).

### Documentation

Documentation for `main` branch is deployed to https://nix-community.github.io/dream2nix.

A CLI app is available if you want to read documentation in your terminal.
The app is available as `d2n-docs` if you enter the development shell, otherwise you can access it with `nix run .#docs`.
`d2n-docs` can be used to access all available documentation.
To access a specific document you can use `d2n-docs doc-name` where `doc-name` is the name of the document.
For example, to access Rust subsystem documentation, you can use `d2n-docs rust`.

You can also build documentation by running `nix build .#docs`.
Or by entering the development shell (`nix develop`) and running `mdbook build docs`.

### Watch the presentation

(The code examples of the presentation are outdated)
[![dream2nix - A generic framework for 2nix tools](https://gist.githubusercontent.com/DavHau/755fed3774e89c0b9b8953a0a25309fa/raw/3c8b2c56f5fca3bf5c343ffc179136eef39d4d6a/dream2nix-youtube-talk.png)](https://www.youtube.com/watch?v=jqCfHMvCsfQ)

### Funding

This project receives financial support by [NLNet](https://nlnet.nl/) as part of the [NGI Assure Programme](https://nlnet.nl/assure/) funded by the European Commission.

If your organization wants to support the project with extra funding in order to add support for more languages or new featuress, please contact one of the maintainers.

### Community

matrix: https://matrix.to/#/#dream2nix:nixos.org

