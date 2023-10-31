{
  inputs,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    self',
    inputs',
    ...
  }: let
    makeDevshell = import "${inputs.devshell}/modules" pkgs;
    mkShell = config:
      (makeDevshell {
        configuration = {
          inherit config;
          imports = [];
        };
      })
      .shell;
  in {
    # a dev shell for working on dream2nix
    # use via 'nix develop . -c $SHELL'
    devShells = {
      default = self'.devShells.dream2nix-shell;
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
          ++ (lib.optionals pkgs.stdenv.isLinux [
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
          ++ lib.optional pkgs.stdenv.isLinux {
            package = pkgs.cntr;
            category = "debugging";
          };

        devshell.startup = {
          preCommitHooks.text = self'.checks.pre-commit-check.shellHook;
          dream2nixEnv.text = ''
            export NIX_PATH=nixpkgs=${inputs.nixpkgs}
          '';
        };
      };
    };
  };
}
