{
  description = "A framework for 2nix tools";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    ### dev dependencies
    alejandra.url = github:kamadorueda/alejandra;
    alejandra.inputs.nixpkgs.follows = "nixpkgs";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    # upstream flake-utils dep not supporting `aarch64-darwin` yet
    flake-utils-pre-commit.url = "github:numtide/flake-utils";
    pre-commit-hooks.inputs.flake-utils.follows = "flake-utils-pre-commit";

    ### framework dependencies
    # required for builder go/gomod2nix
    gomod2nix = {
      url = "github:tweag/gomod2nix";
      flake = false;
    };

    # required for translator pip
    mach-nix = {
      url = "mach-nix";
      flake = false;
    };

    # required for builder nodejs/node2nix
    node2nix = {
      url = "github:svanderburg/node2nix";
      flake = false;
    };

    # required for utils.satisfiesSemver
    poetry2nix = {
      url = "github:nix-community/poetry2nix/1.21.0";
      flake = false;
    };

    # required for builder rust/crane
    crane = {
      url = "github:ipetkov/crane";
      flake = false;
    };
  };

  outputs = {
    self,
    alejandra,
    gomod2nix,
    mach-nix,
    nixpkgs,
    node2nix,
    poetry2nix,
    pre-commit-hooks,
    crane,
    ...
  } @ inp: let
    b = builtins;
    l = lib // builtins;

    lib = nixpkgs.lib;

    # dream2nix lib (system independent utils)
    dlib = import ./src/lib {inherit lib;};

    supportedSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin"];

    forSystems = systems: f:
      lib.genAttrs systems
      (system: f system nixpkgs.legacyPackages.${system});

    forAllSystems = forSystems supportedSystems;

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
      crane = [
        "lib/buildDepsOnly.nix"
        "lib/buildPackage.nix"
        "lib/cargoBuild.nix"
        "lib/cleanCargoToml.nix"
        "lib/findCargoFiles.nix"
        "lib/mkCargoDerivation.nix"
        "lib/mkDummySrc.nix"
        "lib/writeTOML.nix"
        "pkgs/configureCargoCommonVarsHook.sh"
        "pkgs/configureCargoVendoredDepsHook.sh"
        "pkgs/installFromCargoBuildLogHook.sh"
        "pkgs/inheritCargoArtifactsHook.sh"
        "pkgs/installCargoArtifactsHook.sh"
        "pkgs/remapSourcePathPrefixHook.sh"
        "LICENSE"
      ];
    };

    # create a directory containing the files listed in externalPaths
    makeExternalDir = import ./src/utils/external-dir.nix;

    externalDirFor = forAllSystems (system: pkgs:
      makeExternalDir {
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

    overridesDirs = ["${./overrides}"];

    # system specific dream2nix api
    dream2nixFor = forAllSystems (system: pkgs:
      import ./src rec {
        externalDir = externalDirFor."${system}";
        inherit dlib externalPaths externalSources lib pkgs;
        config = {
          inherit overridesDirs;
        };
      });

    pre-commit-check = forAllSystems (
      system: pkgs:
        pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            treefmt = {
              enable = true;
              name = "treefmt";
              pass_filenames = true;
              entry = l.toString (pkgs.writeScript "treefmt" ''
                #!${pkgs.bash}/bin/bash
                export PATH="$PATH:${alejandra.defaultPackage.${system}}/bin"
                ${pkgs.treefmt}/bin/treefmt --fail-on-change "$@"
              '');
            };
          };
        }
    );
  in {
    # System independent dream2nix api.
    # Similar to drem2nixFor but will require 'system(s)' or 'pkgs' as an argument.
    # Produces flake-like output schema.
    lib =
      (import ./src/lib.nix {
        inherit dlib externalPaths externalSources overridesDirs lib;
        nixpkgsSrc = "${nixpkgs}";
      })
      # system specific dream2nix library
      // (forAllSystems (system: pkgs: dream2nixFor."${system}"));

    # with project discovery enabled
    lib2 = import ./src/libV2.nix {
      inherit dlib externalPaths externalSources overridesDirs lib;
      nixpkgsSrc = "${nixpkgs}";
    };

    # the dream2nix cli to be used with 'nix run dream2nix'
    defaultApp =
      forAllSystems (system: pkgs: self.apps."${system}".dream2nix);

    # all apps including cli, install, etc.
    apps = forAllSystems (
      system: pkgs:
        dream2nixFor."${system}".apps.flakeApps
        // {
          tests-impure.type = "app";
          tests-impure.program =
            b.toString
            (dream2nixFor."${system}".callPackageDream ./tests/impure {});

          tests-unit.type = "app";
          tests-unit.program =
            b.toString
            (dream2nixFor."${system}".callPackageDream ./tests/unit {
              inherit self;
            });

          tests-all.type = "app";
          tests-all.program =
            l.toString
            (dream2nixFor.${system}.utils.writePureShellScript
              [
                alejandra.defaultPackage.${system}
                pkgs.coreutils
                pkgs.gitMinimal
                pkgs.nix
              ]
              ''
                echo "running unit tests"
                ${self.apps.${system}.tests-unit.program}

                echo "running impure CLI tests"
                ${self.apps.${system}.tests-impure.program}

                echo "running nix flake check"
                cd $WORKDIR
                nix flake check
              '');

          # passes through extra flags to treefmt
          format.type = "app";
          format.program =
            l.toString
            (pkgs.writeScript "format" ''
              export PATH="${alejandra.defaultPackage.${system}}/bin"
              ${pkgs.treefmt}/bin/treefmt "$@"
            '');
        }
    );

    # a dev shell for working on dream2nix
    # use via 'nix develop . -c $SHELL'
    devShell = forAllSystems (system: pkgs:
      pkgs.mkShell {
        buildInputs =
          (with pkgs; [
            nix
            treefmt
          ])
          ++ [
            alejandra.defaultPackage."${system}"
          ]
          # using linux is highly recommended as cntr is amazing for debugging builds
          ++ lib.optionals pkgs.stdenv.isLinux [pkgs.cntr];

        shellHook =
          # TODO: enable this once code base is formatted
          # self.checks.${system}.pre-commit-check.shellHook
          ''
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

    checks =
      l.recursiveUpdate
      (forAllSystems (system: pkgs: (import ./tests/pure {
        inherit lib pkgs;
        dream2nix = dream2nixFor."${system}";
      })))
      {}
      # TODO: enable this once code base is formatted
      # (forAllSystems (system: pkgs:{
      #   pre-commit-check =
      #     pre-commit-hooks.lib.${system}.run {
      #       src = ./.;
      #       hooks = {
      #         treefmt = {
      #           enable = true;
      #           name = "treefmt";
      #           pass_filenames = false;
      #           entry = l.toString (pkgs.writeScript "treefmt" ''
      #             #!${pkgs.bash}/bin/bash
      #             export PATH="$PATH:${alejandra.defaultPackage.${system}}/bin"
      #             ${pkgs.treefmt}/bin/treefmt --fail-on-change
      #           '');
      #         };
      #       };
      #     };
      # }))
      ;
  };
}
