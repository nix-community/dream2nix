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

    # required for utils.satisfiesSemver
    poetry2nix = { url = "github:nix-community/poetry2nix/1.21.0"; flake = false; };
  };

  outputs = {
    self,
    mach-nix,
    nix-parsec,
    nixpkgs,
    node2nix,
    poetry2nix,
  }@inp:
    let

      b = builtins;

      lib = nixpkgs.lib;

      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];

      forAllSystems = f: lib.genAttrs supportedSystems (system:
        f system (import nixpkgs { inherit system; overlays = [ self.overlay ]; })
      );

      # To use dream2nix in non-flake + non-IFD enabled repos, the source code of dream2nix
      # must be installed into these repos (using nix run dream2nix#install).
      # The problem is, all of dream2nix' dependecies need to be installed as well.
      # Therefore 'externalPaths' contains all relevant files of external projects
      # which dream2nix depends on. Exactly these files will be installed.
      externalPaths = {
        mach-nix = [
          "lib/extractor/default.nix"
          "lib/extractor/distutils.patch"
          "lib/extractor/setuptools.patch"
          "LICENSE"
        ];
        node2nix = [
          "nix/node-env.nix"
          "LICENSE"
        ];
        nix-parsec = [
          "parsec.nix"
          "lexer.nix"
          "LICENSE"
        ];
        poetry2nix = [
          "semver.nix"
          "LICENSE"
        ];
      };

      # create a directory containing the files listed in externalPaths
      makeExternalDir = pkgs: pkgs.runCommand "dream2nix-external" {}
        (lib.concatStringsSep "\n"
          (lib.mapAttrsToList
            (inputName: paths:
              lib.concatStringsSep "\n"
                (lib.forEach
                  paths
                  (path: ''
                    mkdir -p $out/${inputName}/$(dirname ${path})
                    cp ${inp."${inputName}"}/${path} $out/${inputName}/${path}
                  '')))
            externalPaths));

      externalDirFor = forAllSystems (system: makeExternalDir);

      # An interface to access files of external projects.
      # This implementation aceeses the flake inputs directly,
      # but if dream2nix is used without flakes, it defaults
      # to another implementation of that function which
      # uses the installed external paths instead (see default.nix)
      externalSources =
        lib.genAttrs
          (lib.attrNames externalPaths)
          (inputName: inp."${inputName}");

      overridesDirs =  [ "${./overrides}" ];

      # system specific dream2nix api
      dream2nixFor = forAllSystems (system: pkgs: import ./src rec {
        externalDir = externalDirFor."${system}";
        inherit externalSources lib overridesDirs pkgs;
      });

    in
      {
        # overlay with flakes enabled nix
        # (all of dream2nix cli dependends on nix ^2.4)
        overlay = final: prev: {
          nix = prev.writeScriptBin "nix" ''
            ${final.nixUnstable}/bin/nix --option experimental-features "nix-command flakes" "$@"
          '';
        };

        # System independent dream2nix api.
        # Similar to drem2nixFor but will require 'system(s)' or 'pkgs' as an argument.
        # Produces flake-like output schema.
        lib = (import ./src/lib.nix {
          inherit externalSources overridesDirs lib;
          nixpkgsSrc = "${nixpkgs}";
        })
        # system specific dream2nix library
        // (forAllSystems (system: pkgs:
          import ./src {
            inherit
              externalSources
              lib
              overridesDirs
              pkgs
            ;
          }
        ));

        # the dream2nix cli to be used with 'nix run dream2nix'
        defaultApp =
          forAllSystems (system: pkgs: self.apps."${system}".dream2nix);

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
            export d2nExternalDir=${externalDirFor."${system}"}
            export dream2nixWithExternals=${dream2nixFor."${system}".dream2nixWithExternals}
            export d2nOverridesDirs=${./overrides}

            echo -e "\nManually execute 'export dream2nixWithExternals={path to your dream2nix checkout}'"
          '';
        });

        checks = forAllSystems (system: pkgs: import ./checks.nix {
          inherit lib pkgs;
          dream2nix = dream2nixFor."${system}";
        });
      };
}
