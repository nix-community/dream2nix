# evaluate packages from `/**/modules/drvs` and export them via `flake.packages`
{self, ...}: {
  perSystem = {
    pkgs,
    inputs',
    lib,
    system,
    ...
  }: let
    modulesFlake = import "${self}/modules" {};
    inputs = lib.mapAttrs (name: input: "${input.outPath}") modulesFlake.inputs;
    inputsFile = builtins.toFile "inputs.json" (builtins.toJSON inputs);
  in
    lib.optionalAttrs (system == "x86_64-linux") {
      # map all modules in /examples to a package output in the flake.
      checks.nix-unit =
        pkgs.runCommand "nix-unit-tests" {
          nativeBuildInputs = [
            pkgs.nix
          ];
        } ''
          export NIX_PATH=nixpkgs=${pkgs.path}
          export HOME=$(realpath .)
          for test in ${self}/tests/nix-unit/*; do
            if [ -f "$test" ]; then
              continue
            fi
            echo -e "Executing tests from file $test"
            ${inputs'.nix-unit.packages.nix-unit}/bin/nix-unit \
              "$test" \
              --eval-store $(realpath .) \
              --arg inputs 'builtins.fromJSON (builtins.readFile ${inputsFile})'
          done
          touch $out
        '';
    };
}
