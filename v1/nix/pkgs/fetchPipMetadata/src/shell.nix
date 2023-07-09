{
  nixpkgs ? (import ../../../../..).inputs.nixpkgs,
  system ? builtins.currentSystem,
}: let
  lib = nixpkgs.lib;
  pkgs = nixpkgs.legacyPackages.${system};
  python = pkgs.python3;
  package = import ../package.nix {
    inherit lib python;
  };
  pythonWithDeps = python.withPackages (
    ps:
      package.propagatedBuildInputs
      ++ [
        ps.black
        ps.pytest
      ]
  );
  devShell = pkgs.mkShell {
    packages = [
      pythonWithDeps
    ];
  };
in
  devShell
