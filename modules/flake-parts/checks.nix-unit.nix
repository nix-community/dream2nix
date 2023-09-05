# evaluate packages from `/**/modules/drvs` and export them via `flake.packages`
{self, ...}: {
  perSystem = {
    pkgs,
    inputs',
    ...
  }: {
    # map all modules in /examples to a package output in the flake.
    checks.nix-unit = pkgs.runCommand "nix-unit-tests" {} ''
      export NIX_PATH=nixpkgs=${pkgs.path}
      for test in ${self}/tests/nix-unit/*; do
        echo -e "Executing tests from file $test"
        ${inputs'.nix-unit.packages.nix-unit}/bin/nix-unit \
          "$test" \
          --eval-store $(realpath .)
      done
      touch $out
    '';
  };
}
