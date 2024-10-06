{
  config,
  lib,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.buildPythonPackage-mixin
    dream2nix.modules.dream2nix.core
  ];
  name = "test";
  version = "1.0.0";
  phases = ["buildPhase"];
  buildPhase = "echo -n hello > $out && cp $out $dist";
  format = "setuptools";
}
