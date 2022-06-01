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
2. Navigate to to the project intended to be packaged and initialize a dream2nix flake:
    ```command
      cd ./my-project
      nix flake init -t github:nix-community/dream2nix#simple
    ```
3. List the packages that can be built
    ```command
      nix flake show
    ```


Minimal Example `flake.nix`:
```nix
{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = { self, dream2nix }@inputs:
    dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      # config.projectRoot defaults to source
      source = ./.;
    };
}
```

Extensive Example `flake.nix`:
```nix
{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = { self, dream2nix }:
    let
      nixpkgs = dream2nix.inputs.nixpkgs;
      l = nixpkgs.lib // builtins;

      allPkgs =
        l.map
        (system: nixpkgs.legacyPackages.${system})
        ["x86_64-linux"];

      # shorthand function to create a dream2nix instance from
      # some pkgs set.
      #
      # the 'init' function takes a 'pkgs' and a 'config' and
      # outputs a dream2nix instance.
      initD2N = pkgs: dream2nix.lib.init {
        inherit pkgs;
        config.projectRoot = ./.;
      };

      makeOutputs = pkgs: (initD2N pkgs).makeOutputs {
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

      # systemize the outputs produced in makeOutputs
      # so that they fit the flake output structure
      makeSystemOutputs = pkgs: {
        name = pkgs.system;
        value =
          l.mapAttrs
          (_: attrs: {${pkgs.system} = attrs;})
          (makeOutputs pkgs);
      };
      allOutputs = l.map makeSystemOutputs allPkgs;
      outputs = l.foldl' l.recursiveUpdate {} allOutputs;
    in
      outputs;
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
- [Extending dream2nix](/docs/extending-dream2nix.md)

### Funding
This project receives financial support by [NLNet](https://nlnet.nl/) as part of the [NGI Assure Programme](https://nlnet.nl/assure/) funded by the European Commission.

If your organization wants to support the project with extra funding in order to add support for more languages or new featuress, please contact one of the maintainers.

### Community
matrix: https://matrix.to/#/#dream2nix:nixos.org

