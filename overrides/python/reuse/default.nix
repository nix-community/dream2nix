{
  config,
  lib,
  dream2nix,
  ...
}: let
  isSdist = lib.hasSuffix ".tar.gz" config.mkDerivation.src;
  inherit (config.deps) python;
in {
  buildPythonPackage.pyproject = lib.mkIf isSdist true;
  mkDerivation.nativeBuildInputs = lib.mkIf isSdist [python.pkgs.poetry-core];
}
