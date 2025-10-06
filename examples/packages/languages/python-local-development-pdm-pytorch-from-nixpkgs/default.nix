# An example package with dependencies defined via pyproject.toml
{
  config,
  lib,
  dream2nix,
  ...
}: let
  inherit (config.deps) python;
  nixpkgsTorch = python.pkgs.torch;
  torchWheel = config.deps.runCommand "torch-wheel" {} ''
    file="$(ls "${nixpkgsTorch.dist}")"
    mkdir "$out"
    cp "${nixpkgsTorch.dist}/$file" "$out/$file"
  '';
in {
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

  buildPythonPackage = {
    pythonImportsCheck = [
      "my_tool"
    ];
  };

  # Override for torch to pick the wheel from nixpkgs instead of pypi
  overrides.torch = {
    mkDerivation = {
      src = torchWheel;
      prePhases = ["selectWheelFile"];
      inherit (nixpkgsTorch) buildInputs;
    };
    buildPythonPackage = {
      format = "wheel";
      pyproject = null;
    };
  };
}
