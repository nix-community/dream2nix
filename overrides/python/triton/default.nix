{
  config,
  lib,
  ...
}: {
  env.pythonRemoveDeps = [
    "torch"
  ];
  mkDerivation.nativeBuildInputs = [
    config.deps.python.pkgs.pythonRelaxDepsHook
  ];
}
