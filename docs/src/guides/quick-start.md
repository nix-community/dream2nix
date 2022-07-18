## Test the experimental version of dream2nix

(Currently only nodejs, python and rust packaging is supported)

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
