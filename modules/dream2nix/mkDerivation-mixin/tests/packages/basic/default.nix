{dream2nix, ...}: {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation-mixin
    dream2nix.modules.dream2nix.core
  ];
  name = "test";
  version = "1.0.0";
  phases = ["buildPhase"];
  buildPhase = "echo -n hello > $out";
}
