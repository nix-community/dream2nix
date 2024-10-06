{
  config,
  lib,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.buildPythonPackage
    dream2nix.modules.dream2nix.core
  ];
  name = "test";
  version = "1.0.0";
  mkDerivation.phases = ["buildPhase"];
  buildPythonPackage.format = "setuptools";
  mkDerivation.buildPhase = "echo -n hello > $out && cp $out $dist";
}
