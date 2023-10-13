{
  description = "A framework for 2nix tools";

  nixConfig = {
    extra-trusted-public-keys = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    extra-substituters = "https://nix-community.cachix.org";
  };

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

    nix-unit.url = "github:adisbladis/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    nix-unit.inputs.flake-parts.follows = "flake-parts";

    devshell = {
      url = "github:numtide/devshell";
      flake = false;
    };
  };

  outputs = {
    self,
    devshell,
    flake-parts,
    nixpkgs,
    pre-commit-hooks,
    ...
  } @ inp: let
    l = nixpkgs.lib // builtins;

    inputs = inp;

    perSystem = {
      config,
      pkgs,
      system,
      inputs',
      ...
    }: {
      apps = {
        # passes through extra flags to treefmt
        format.type = "app";
        format.program = let
          path = l.makeBinPath [
            pkgs.alejandra
            pkgs.python3.pkgs.black
          ];
        in
          l.toString
          (pkgs.writeScript "format" ''
            export PATH="${path}"
            ${pkgs.treefmt}/bin/treefmt --clear-cache "$@"
          '');
      };

      # a dev shell for working on dream2nix
      # use via 'nix develop . -c $SHELL'
      devShells = let
        makeDevshell = import "${inp.devshell}/modules" pkgs;
        mkShell = config:
          (makeDevshell {
            configuration = {
              inherit config;
              imports = [];
            };
          })
          .shell;
      in rec {
        default = dream2nix-shell;
        dream2nix-shell = mkShell {
          devshell.name = "dream2nix-devshell";

          packages =
            [
              pkgs.alejandra
              pkgs.mdbook
              (pkgs.python3.withPackages (ps: [
                pkgs.python3.pkgs.black
              ]))
            ]
            ++ (l.optionals pkgs.stdenv.isLinux [
              inputs'.nix-unit.packages.nix-unit
            ]);

          commands =
            [
              {
                package = pkgs.treefmt;
                category = "formatting";
              }
            ]
            # using linux is highly recommended as cntr is amazing for debugging builds
            ++ l.optional pkgs.stdenv.isLinux {
              package = pkgs.cntr;
              category = "debugging";
            };

          devshell.startup = {
            preCommitHooks.text = self.checks.${system}.pre-commit-check.shellHook;
            dream2nixEnv.text = ''
              export NIX_PATH=nixpkgs=${nixpkgs}
            '';
          };
        };
      };

      checks = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            treefmt = {
              enable = true;
              name = "treefmt";
              pass_filenames = false;
              entry = l.toString (pkgs.writeScript "treefmt" ''
                #!${pkgs.bash}/bin/bash
                export PATH="$PATH:${l.makeBinPath [
                  pkgs.alejandra
                  pkgs.python3.pkgs.black
                ]}"
                ${pkgs.treefmt}/bin/treefmt --clear-cache --fail-on-change
              '');
            };
          };
        };
      };

      packages = {
        docs =
          pkgs.runCommand
          "dream2nix-docs"
          {nativeBuildInputs = [pkgs.bash pkgs.mdbook];}
          ''
            bash -c "
            errors=$(mdbook build -d $out ${./.}/docs |& grep ERROR)
            if [ \"$errors\" ]; then
              exit 1
            fi
            "
          '';
      };
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./modules/flake-parts/all-modules.nix
        ./pkgs/fetchPipMetadata/flake-module.nix
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      inherit perSystem;
    };
}
