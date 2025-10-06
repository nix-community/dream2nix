{
  config,
  lib,
  dream2nix,
  ...
}: let
  editables = lib.filterAttrs (_name: path: path) config.editables;
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.deps
  ];
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) unzip writeText mkShell;
    python = nixpkgs.python3;
  };
  editablesShellHook = import ./editable.nix {
    inherit lib;
    inherit (config.deps) unzip writeText;
    inherit (config.paths) findRoot;
    inherit (config) editables pyEnv;
    rootName = config.name;
  };
}
