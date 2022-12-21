{
  description = "A framework for 2nix tools";

  nixConfig = {
    extra-trusted-public-keys = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    extra-substituters = "https://nix-community.cachix.org";
  };

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    ### dev dependencies
    alejandra.url = "github:kamadorueda/alejandra";
    alejandra.inputs.nixpkgs.follows = "nixpkgs";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils-pre-commit.url = "github:numtide/flake-utils";
    pre-commit-hooks.inputs.flake-utils.follows = "flake-utils-pre-commit";

    devshell = {
      url = "github:numtide/devshell";
      flake = false;
    };

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

    # required for pinned python translator
    nix-pypi-fetcher = {
      url = "github:DavHau/nix-pypi-fetcher";
      flake = false;
    };

    # required for utils.satisfiesSemver
    poetry2nix = {
      url = "github:nix-community/poetry2nix/1.36.0";
      flake = false;
    };

    # required for builder rust/crane
    crane = {
      url = "github:ipetkov/crane";
      flake = false;
    };

    # required for haskell translators
    all-cabal-json = {
      url = "github:nix-community/all-cabal-json/hackage";
      flake = false;
    };

    ghc-utils = {
      url = "git+https://gitlab.haskell.org/bgamari/ghc-utils";
      flake = false;
    };
  };

  outputs = {
    self,
    alejandra,
    devshell,
    flake-parts,
    gomod2nix,
    mach-nix,
    nixpkgs,
    poetry2nix,
    pre-commit-hooks,
    crane,
    all-cabal-json,
    ghc-utils,
    ...
  } @ inp: let
    l = lib // builtins;

    lib = nixpkgs.lib;

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
      poetry2nix = [
        "lib.nix"
        "pep425.nix"
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
        "lib/setupHooks/cargoHelperFunctionsHook.sh"
        "lib/setupHooks/configureCargoCommonVarsHook.sh"
        "lib/setupHooks/configureCargoVendoredDepsHook.sh"
        "lib/setupHooks/installFromCargoBuildLogHook.sh"
        "lib/setupHooks/inheritCargoArtifactsHook.sh"
        "lib/setupHooks/installCargoArtifactsHook.sh"
        "LICENSE"
      ];
    };

    # An interface to access files of external projects.
    # This implementation accesses the flake inputs directly,
    # but if dream2nix is used without flakes, it defaults
    # to another implementation of that function which
    # uses the installed external paths instead (see default.nix)
    externalSources =
      lib.genAttrs
      (lib.attrNames externalPaths)
      (inputName: inp."${inputName}");

    /*
    Inputs that are not required for building, and therefore not need to be
    copied alongside a dream2nix installation.
    */
    inputs = inp;

    overridesDirs = [(toString ./overrides)];

    # System independent dream2nix api.
    # Produces flake-like output schema.
    d2n-lib = import ./src/lib.nix {
      inherit externalPaths externalSources inputs overridesDirs lib;
      nixpkgsSrc = "${nixpkgs}";
    };

    perSystem = {
      config,
      pkgs,
      system,
      ...
    }: let
      d2n = import ./src {
        inherit externalPaths externalSources inputs lib pkgs;
        dream2nixConfig = {inherit overridesDirs;};
      };
      docsCli = pkgs.callPackage ./src/utils/view-docs {
        dream2nixDocsSrc = "${self}/docs/src";
      };
    in {
      options = {
        d2n = l.mkOption {
          type = l.types.raw;
        };
      };
      config = {
        inherit d2n;

        # all apps including cli, install, etc.
        apps =
          d2n.flakeApps
          // {
            # passes through extra flags to treefmt
            format.type = "app";
            format.program =
              l.toString
              (pkgs.writeScript "format" ''
                export PATH="${alejandra.defaultPackage.${system}}/bin"
                ${pkgs.treefmt}/bin/treefmt --clear-cache "$@"
              '');

            docs.type = "app";
            docs.program = "${docsCli}/bin/d2n-docs";
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

            commands =
              [
                {package = pkgs.nix;}
                {
                  package = pkgs.mdbook;
                  category = "documentation";
                }
                {
                  package = docsCli;
                  category = "documentation";
                  help = "CLI for listing and viewing dream2nix documentation";
                }
                {
                  package = pkgs.treefmt;
                  category = "formatting";
                }
                {
                  package = alejandra.defaultPackage.${system};
                  category = "formatting";
                }
              ]
              # using linux is highly recommended as cntr is amazing for debugging builds
              ++ lib.optional pkgs.stdenv.isLinux {
                package = pkgs.cntr;
                category = "debugging";
              };

            devshell.startup = {
              preCommitHooks.text = self.checks.${system}.pre-commit-check.shellHook;
              dream2nixEnv.text = ''
                export NIX_PATH=nixpkgs=${nixpkgs}
                export d2nExternalDir=${d2n.externalDir}
                export dream2nixWithExternals=${d2n.dream2nixWithExternals}

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
                  export PATH="$PATH:${alejandra.defaultPackage.${system}}/bin"
                  ${pkgs.treefmt}/bin/treefmt --clear-cache --fail-on-change
                '');
              };
              cleanup = {
                enable = true;
                name = "cleaned";
                entry = l.toString (pkgs.writeScript "cleaned" ''
                  #!${pkgs.bash}/bin/bash
                  for badFile in  $(find ./examples | grep 'flake.lock\|dream2nix-packages'); do
                    rm -rf $badFile
                    git add $badFile || :
                  done
                '');
              };
              is-cleaned = {
                enable = true;
                name = "is-cleaned";
                entry = l.toString (pkgs.writeScript "is-cleaned" ''
                  #!${pkgs.bash}/bin/bash
                  if find ./examples | grep -q 'flake.lock\|dream2nix-packages'; then
                    echo "./examples should not contain any flake.lock files or dream2nix-packages directories" >&2
                    exit 1
                  fi
                '');
              };
            };
          };
        };
        packages = {
          docs =
            pkgs.runCommand
            "dream2nix-docs"
            {nativeBuildInputs = [pkgs.mdbook];}
            ''
              mdbook build -d $out ${./.}/docs
            '';
        };
      };
    };

    flake = {
      lib = d2n-lib;
      # kept for compat
      lib2 = d2n-lib;

      flakeModuleBeta = {
        imports = [./src/modules/flake-parts];
        dream2nix.lib = d2n-lib;
      };
    };
  in
    flake-parts.lib.mkFlake {inherit self;} {
      imports = [
        ./tests
        ./templates
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      inherit flake perSystem;
    };
}
