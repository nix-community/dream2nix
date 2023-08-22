{
  nixpkgs ? (import ../../..).inputs.nixpkgs,
  system ? builtins.currentSystem,
}: let
  lib = nixpkgs.lib;
  pkgs = nixpkgs.legacyPackages.${system};
  python = pkgs.python3;
  package = import ../package.nix {
    inherit lib python;
    inherit (pkgs) git;
  };
  pythonWithDeps = python.withPackages (
    ps:
      package.propagatedBuildInputs
      ++ [
        ps.black
        ps.pytest
        ps.pytest-cov
      ]
  );
  devShell = pkgs.mkShell {
    packages = [
      pythonWithDeps
    ];
  };
in
  devShell
