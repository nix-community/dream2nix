{dream2nix, ...}: {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.core
  ];
  name = "test";
  version = "1.0.0";
  mkDerivation.phases = ["buildPhase"];
  mkDerivation.buildPhase = "echo -n hello > $out";
}
