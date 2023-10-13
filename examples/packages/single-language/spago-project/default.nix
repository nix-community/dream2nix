{dream2nix, ...}: {
  imports = [
    dream2nix.modules.dream2nix.WIP-spago
  ];

  name = "test";
  version = "1.0.0";

  mkDerivation = {
    src = ./.;
  };
}
