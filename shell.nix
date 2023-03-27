(import ./default.nix).devShells.${builtins.currentSystem}.default
or (throw "dev-shell not defined. Cannot find flake attribute devShell.${builtins.currentSystem}.default")
