{ config, dream2nix, lib, ... }: {
  imports = [
    dream2nix.modules.dream2nix.WIP-haskell-cabal
  ];

  name = "my-test-project";
  version = "1.0.0";

  deps = { nixpkgs, ... }: {
    haskell-compiler = nixpkgs.haskell.compiler.ghc946;
    inherit (nixpkgs) zlib;
  };

  mkDerivation = {
    src = lib.cleanSourceWith {
      src = lib.cleanSource ./.;
      filter = name: type:
        let baseName = baseNameOf (toString name); in
          !(
            lib.hasSuffix ".nix" baseName
            || lib.hasSuffix ".md" baseName
          );
    };

    buildInputs = [ config.deps.zlib ];
  };
}
