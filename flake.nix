{
  description = "dream2nix: A generic framework for 2nix tools";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let

      lib = nixpkgs.lib; 

      supportedSystems = [ "x86_64-linux" ];

      forAllSystems = f: lib.genAttrs supportedSystems (system: f system);

      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });

      dream2nixFor = forAllSystems (system: import ./src { pkgs = nixpkgsFor."${system}"; } );

    in
      {
        overlay = curr: prev: {};

        apps = forAllSystems (system: {
          translate = {
            "type" = "app";
            "program" = builtins.toString (dream2nixFor."${system}".apps.translate);
          };
          install = {
            "type" = "app";
            "program" = builtins.toString (dream2nixFor."${system}".apps.install);
          };
        });
      };
}
