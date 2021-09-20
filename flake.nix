{
  description = "dream2nix: A generic framework for 2nix tools";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    node2nix = { url = "github:svanderburg/node2nix"; flake = false; };
    npmlock2nix = { url = "github:nix-community/npmlock2nix"; flake = false; };
  };

  outputs = { self, nixpkgs, node2nix, npmlock2nix }:
    let

      lib = nixpkgs.lib;

      supportedSystems = [ "x86_64-linux" ];

      forAllSystems = f: lib.genAttrs supportedSystems (system: f system);

      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });

      externalSourcesFor = forAllSystems (system: nixpkgsFor."${system}".runCommand "dream2nix-vendored" {} ''
        mkdir -p $out/{npmlock2nix,node2nix}
        cp ${npmlock2nix}/{internal.nix,LICENSE} $out/npmlock2nix/
        cp ${node2nix}/{nix/node-env.nix,LICENSE} $out/node2nix/
      '');

      dream2nixFor = forAllSystems (system: import ./src rec {
        pkgs = nixpkgsFor."${system}";
        externalSources = externalSourcesFor."${system}";
        inherit lib;
      });

    in
      {
        overlay = curr: prev: {};

        lib.dream2nix = dream2nixFor;

        defaultApp = forAllSystems (system: self.apps."${system}".cli);

        apps = forAllSystems (system: {
          cli = {
            "type" = "app";
            "program" = builtins.toString (dream2nixFor."${system}".apps.cli);
          };
          install = {
            "type" = "app";
            "program" = builtins.toString (dream2nixFor."${system}".apps.install);
          };
        });

        devShell = forAllSystems (system: nixpkgsFor."${system}".mkShell {
          buildInputs = with nixpkgsFor."${system}"; [
            nixUnstable
          ];
          shellHook = ''
            export NIX_PATH=nixpkgs=${nixpkgs}
            export d2nExternalSources=${externalSourcesFor."${system}"}
          '';
        });
      };
}
