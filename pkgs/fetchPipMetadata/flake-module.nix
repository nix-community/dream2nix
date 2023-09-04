{
  perSystem = {
    self',
    pkgs,
    lib,
    ...
  }: let
    python3 = pkgs.python310;
  in {
    devShells.fetch-pip-metadata = let
      package = self'.packages.fetch-pip-metadata-package;
      pythonWithDeps = python3.withPackages (
        ps:
          package.propagatedBuildInputs
          ++ [
            ps.black
            ps.pytest
            ps.pytest-cov
          ]
      );
    in
      pkgs.mkShell {
        packages = [
          pythonWithDeps
        ];
      };

    packages.fetch-pip-metadata-package = import ./package.nix {
      inherit lib;
      inherit python3;
      inherit (pkgs) gitMinimal;
    };
  };
}
