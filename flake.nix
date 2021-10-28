{
  description = "dream2nix: A generic framework for 2nix tools";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    
    # required for translator nodejs/pure/package-lock
    nix-parsec = { url = "github:nprindle/nix-parsec"; flake = false; };

    # required for translator pip
    mach-nix = { url = "mach-nix"; flake = false; };

    # required for builder nodejs/node2nix
    node2nix = { url = "github:svanderburg/node2nix"; flake = false; };
  };

  outputs = { self, mach-nix, nix-parsec, nixpkgs, node2nix, }:
    let

      b = builtins;

      lib = nixpkgs.lib;

      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];

      forAllSystems = f: lib.genAttrs supportedSystems (system:
        f system (import nixpkgs { inherit system; overlays = [ self.overlay ]; })
      );

      # To use dream2nix in non-flake + non-IFD enabled repos, the source code of dream2nix
      # must be installed into that repo (using nix run dream2nix#install).
      # The problem is, we also need to install all of dream2nix' dependecies as well.
      # Therefore 'externalSourcesFor' contains all relevant files of external projects we depend on.
      makeExternalSources = pkgs: pkgs.runCommand "dream2nix-external" {} ''
        mkdir -p $out/{mach-nix-lib,node2nix,nix-parsec}
        cp ${mach-nix}/{lib/extractor/{default.nix,distutils.patch,setuptools.patch},LICENSE} $out/mach-nix-lib/
        cp ${node2nix}/{nix/node-env.nix,LICENSE} $out/node2nix/
        cp ${nix-parsec}/{parsec,lexer}.nix $out/nix-parsec/
      '';

      externalSourcesFor = forAllSystems (system: makeExternalSources);

      # system specific dream2nix api
      dream2nixFor = forAllSystems (system: pkgs: import ./src rec {
        externalSources = externalSourcesFor."${system}";
        inherit pkgs;
        inherit lib;
      });

    in
      {
        # overlay with flakes enabled nix
        # (all of dream2nix cli dependends on nix ^2.4)
        overlay = new: old: {
          nix = old.writeScriptBin "nix" ''
            ${new.nixUnstable}/bin/nix --option experimental-features "nix-command flakes" "$@"
          '';
        };

        # System independent dream2nix api.
        # Similar to drem2nixFor but will require 'system(s)' or 'pkgs' as an argument.
        # Produces flake-like output schema.
        lib.dream2nix = import ./src/lib.nix {
          inherit makeExternalSources lib;
          nixpkgsSrc = "${nixpkgs}";
        };

        # the dream2nix cli to be used with 'nix run dream2nix'
        defaultApp = forAllSystems (system: pkgs: self.apps."${system}".cli);

        # all apps including cli, install, etc.
        apps = forAllSystems (system: pkgs:
          lib.mapAttrs (appName: app:
            {
              type = "app";
              program = b.toString app.program;
            }
          ) dream2nixFor."${system}".apps.apps
        );

        # a dev shell for working on dream2nix
        # use via 'nix develop . -c $SHELL'
        devShell = forAllSystems (system: pkgs: pkgs.mkShell {

          buildInputs = with pkgs;
            (with pkgs; [
              nixUnstable
            ])
            # using linux is highly recommended as cntr is amazing for debugging builds
            ++ lib.optionals stdenv.isLinux [ cntr ];

          shellHook = ''
            export NIX_PATH=nixpkgs=${nixpkgs}
            export d2nExternalSources=${externalSourcesFor."${system}"}
            export dream2nixWithExternals=${dream2nixFor."${system}".dream2nixWithExternals}
            export d2nExternalSources=$dream2nixWithExternals/external

            echo "\nManually execute 'export dream2nixWithExternals={path to your dream2nix checkout}'"
          '';
        });
      };
}
