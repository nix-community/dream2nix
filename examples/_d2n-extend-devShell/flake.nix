{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    src.url = "github:prettier/prettier/2.4.1";
    src.flake = false;
  };

  outputs = {
    self,
    dream2nix,
    src,
  } @ inp: let
    nixpkgs = dream2nix.inputs.nixpkgs;
    l = nixpkgs.lib // builtins;

    systems = ["x86_64-linux"];
    forAllSystems = f:
      l.genAttrs systems (
        system:
          f system (nixpkgs.legacyPackages.${system})
      );

    d2n-flake = dream2nix.lib.makeFlakeOutputs {
      inherit systems;
      config.projectRoot = ./.;
      source = src;
    };
  in
    dream2nix.lib.dlib.mergeFlakes [
      d2n-flake
      {
        devShells = forAllSystems (system: pkgs: (
          l.optionalAttrs
          (d2n-flake ? devShells.${system}.prettier.overrideAttrs)
          {
            prettier =
              d2n-flake.devShells.${system}.prettier.overrideAttrs
              (old: {
                buildInputs =
                  old.buildInputs
                  ++ [
                    pkgs.hello
                  ];
              });
          }
        ));
      }
      {
        # checks.x86_64-linux.prettier = self.packages.x86_64-linux.prettier;
      }
    ];
}
