# An example package with dependencies defined via pyproject.toml
{
  config,
  lib,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.WIP-python-pdm


    # output derivation with python binary including libs, instead of buildPythonPackage
    # config.* changes need to happen as import-module, not within final module
    ({
      config,
      lib,
      ...
    }: {
      config = {
        package-func.func = lib.mkForce (
          {...}:
            config.public.pyEnv
        );
      };
    })
  ];

  mkDerivation = {
    src = lib.cleanSourceWith {
      src = lib.cleanSource ./.;
      filter = name: type:
        !(builtins.any (x: x) [
          (lib.hasSuffix ".nix" name)
          (lib.hasPrefix "." (builtins.baseNameOf name))
          (lib.hasSuffix "flake.lock" name)
        ]);
    };
  };
  pdm.lockfile = ./pdm.lock;
  pdm.pyproject = ./pyproject.toml;
}
