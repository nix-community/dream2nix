{
  description = "A framework for 2nix tools";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    # required for builder go/gomod2nix
    gomod2nix = { url = "github:tweag/gomod2nix"; flake = false; };

    # required for translator pip
    mach-nix = { url = "mach-nix"; flake = false; };

    # required for builder nodejs/node2nix
    node2nix = { url = "github:svanderburg/node2nix"; flake = false; };

    # required for utils.satisfiesSemver
    poetry2nix = { url = "github:nix-community/poetry2nix/1.21.0"; flake = false; };
  };

  outputs = {
    self,
    gomod2nix,
    mach-nix,
    nixpkgs,
    node2nix,
    poetry2nix,
  }@inp:
    let

      b = builtins;

      lib = nixpkgs.lib;

      # dream2nix lib (system independent utils)
      dlib = import ./src/lib { inherit lib; };

      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];

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
        poetry2nix = [
          "semver.nix"
          "LICENSE"
        ];
      };

      # create a directory containing the files listed in externalPaths
      makeExternalDir = import ./src/utils/external-dir.nix;

      externalDirFor = forAllSystems (system: pkgs: makeExternalDir {
        inherit externalPaths externalSources pkgs;
      });

      # An interface to access files of external projects.
      # This implementation accesses the flake inputs directly,
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
        inherit dlib externalPaths externalSources lib pkgs;
        config = {
          inherit overridesDirs;
        };
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
          inherit dlib externalPaths externalSources overridesDirs lib;
          nixpkgsSrc = "${nixpkgs}";
        })
        # system specific dream2nix library
        // (forAllSystems (system: pkgs: dream2nixFor."${system}"));

        # with project discovery enabled
        lib2 = (import ./src/libV2.nix {
          inherit dlib externalPaths externalSources overridesDirs lib;
          nixpkgsSrc = "${nixpkgs}";
        });

        # the dream2nix cli to be used with 'nix run dream2nix'
        defaultApp =
          forAllSystems (system: pkgs: self.apps."${system}".dream2nix);

        # all apps including cli, install, etc.
        apps = forAllSystems (system: pkgs:
          dream2nixFor."${system}".apps.flakeApps // {
            tests-impure.type = "app";
            tests-impure.program = b.toString
              (dream2nixFor."${system}".callPackageDream ./tests/impure {});
            tests-unit.type = "app";
            tests-unit.program = b.toString
              (dream2nixFor."${system}".callPackageDream ./tests/unit {
                inherit self;
              });
          }
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

            if [ -e ./overrides ]; then
              export d2nOverridesDir=$(realpath ./overrides)
            else
              export d2nOverridesDir=${./overrides}
              echo -e "\nManually execute 'export d2nOverridesDir={path to your dream2nix overrides dir}'"
            fi

            if [ -e ../dream2nix ]; then
              export dream2nixWithExternals=$(realpath ./src)
            else
              export dream2nixWithExternals=${./src}
              echo -e "\nManually execute 'export dream2nixWithExternals={path to your dream2nix checkout}'"
            fi
          '';
        });

        checks = forAllSystems (system: pkgs: import ./tests/pure {
          inherit lib pkgs;
          dream2nix = dream2nixFor."${system}";
        });
      };
}
