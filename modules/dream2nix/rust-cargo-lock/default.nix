{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  cfg = config.rust-cargo-lock;
  parseSpdxId = import ../../flake-parts/lib/internal/parseSpdxId.nix {inherit lib;};
  sanitizePath = import ../../flake-parts/lib/internal/sanitizePath.nix {inherit lib;};
  sanitizeRelativePath = import ../../flake-parts/lib/internal/sanitizeRelativePath.nix {inherit lib;};
  prepareSourceTree = import ../../flake-parts/lib/internal/prepareSourceTree.nix {inherit lib;};
  simpleTranslate2 = import ../../flake-parts/lib/internal/simpleTranslate2.nix {inherit lib;};

  translate = import ./translate.nix {
    inherit lib parseSpdxId sanitizePath sanitizeRelativePath simpleTranslate2;
  };

  dreamLock = translate {
    projectRelPath = "";
    tree = prepareSourceTree {source = cfg.source;};
  };
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.mkDerivation
  ];
  rust-cargo-lock = {
    inherit dreamLock;
  };
}
