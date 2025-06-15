# An example package with dependencies defined via pyproject.toml
{
  config,
  lib,
  dream2nix,
  ...
}: let
  python = config.deps.python;
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
    mkDerivation.src = torchWheel;
    # This hack is needed to put the right filename into the src attribute.
    # We cannot know the exact wheel filename upfront, as it is system dependent.
    mkDerivation.prePhases = ["selectWheelFile"];
    env.selectWheelFile = ''
      export src="$src/$(ls $src)"
    '';
    # The original build inputs of torch are required for the autoPatchelf phase
    mkDerivation.buildInputs = nixpkgsTorch.buildInputs;
    buildPythonPackage = {
      format = "wheel";
      pyproject = null;
    };
  };
}
