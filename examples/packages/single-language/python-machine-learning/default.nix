{
  dream2nix,
  config,
  lib,
  ...
}: let
  pyproject =
    builtins.fromTOML
    (builtins.readFile (config.mkDerivation.src + /pyproject.toml));
in {
  imports = [
    dream2nix.modules.dream2nix.WIP-python-pyproject
  ];

  mkDerivation = {
    src = ./.;
  };

  pip.drvs.triton.env.pythonRemoveDeps = [
    "torch"
  ];
  pip.drvs.triton.mkDerivation.nativeBuildInputs = [
    config.deps.python.pkgs.pythonRelaxDepsHook
  ];
  pip.drvs.torch.env.autoPatchelfIgnoreMissingDeps = ["libcuda.so.1"];
  pip.drvs.torch.mkDerivation.dontStrip = true;
}
