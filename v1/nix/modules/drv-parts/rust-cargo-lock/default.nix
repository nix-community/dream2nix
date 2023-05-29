{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  cfg = config.rust-cargo-lock;
  parseSpdxId = import ../../../lib/internal/parseSpdxId.nix {inherit lib;};
  sanitizePath = import ../../../lib/internal/sanitizePath.nix {inherit lib;};
  sanitizeRelativePath = import ../../../lib/internal/sanitizeRelativePath.nix {inherit lib;};
  prepareSourceTree = import ../../../lib/internal/prepareSourceTree.nix {inherit lib;};
  simpleTranslate2 = import ../../../lib/internal/simpleTranslate2.nix {inherit lib;};

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
    dream2nix.modules.drv-parts.mkDerivation
  ];
  rust-cargo-lock = {
    inherit dreamLock;
  };
}
