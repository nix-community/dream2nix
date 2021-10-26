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

    # required for translator nodejs/pure/npmlock2nix
    npmlock2nix = { url = "github:nix-community/npmlock2nix"; flake = false; };
  };

  outputs = { self, mach-nix, nix-parsec, nixpkgs, node2nix, npmlock2nix }:
    let

      lib = nixpkgs.lib;

      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];

      forAllSystems = f: lib.genAttrs supportedSystems (system:
        f system (import nixpkgs { inherit system; overlays = [ self.overlay ]; })
      );

      externalSourcesFor = forAllSystems (system: pkgs: pkgs.runCommand "dream2nix-vendored" {} ''
        mkdir -p $out/{mach-nix-lib,npmlock2nix,node2nix,nix-parsec}
        cp ${mach-nix}/{lib/extractor/{default.nix,distutils.patch,setuptools.patch},LICENSE} $out/mach-nix-lib/
        cp ${npmlock2nix}/{internal.nix,LICENSE} $out/npmlock2nix/
        cp ${node2nix}/{nix/node-env.nix,LICENSE} $out/node2nix/
        cp ${nix-parsec}/{parsec,lexer}.nix $out/nix-parsec/
      '');

      dream2nixFor = forAllSystems (system: pkgs: import ./src rec {
        externalSources = externalSourcesFor."${system}";
        inherit pkgs;
        inherit lib;
      });

    in
      {
        overlay = new: old: {
          nix = old.writeScriptBin "nix" ''
            ${new.nixUnstable}/bin/nix --option experimental-features "nix-command flakes" "$@"
          '';
        };

        lib.dream2nix = dream2nixFor;

        defaultApp = forAllSystems (system: pkgs: self.apps."${system}".cli);

        apps = forAllSystems (system: pkgs:
          lib.mapAttrs (appName: app:
            {
              type = "app";
              program = builtins.toString app.program;
            }
          ) dream2nixFor."${system}".apps.apps
        );

        devShell = forAllSystems (system: pkgs: pkgs.mkShell {

          buildInputs = with pkgs;
            (with pkgs; [
              nixUnstable
            ])
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
