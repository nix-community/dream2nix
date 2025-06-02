{lib, ...}: {
  options = {
    sourceSelector = import ./sourceSelectorOption.nix {inherit lib;};
  };
}
