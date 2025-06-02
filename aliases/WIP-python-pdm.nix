{dream2nix, ...}: {
  imports = [dream2nix.modules.dream2nix.python-pdm];
  warnings = [
    "The dream2nix module `WIP-python-pdm` has been renamed to `python-pdm`."
  ];
}
