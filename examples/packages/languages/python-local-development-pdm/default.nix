# An example package with dependencies defined via pyproject.toml
{
  config,
  lib,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.WIP-python-pdm
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

  # specify which pyproject.toml group to use (examples: default, extra, test)
  # pdm.group = "test";

  buildPythonPackage = {
    pythonImportsCheck = [
      "my_tool"
    ];
  };
}
