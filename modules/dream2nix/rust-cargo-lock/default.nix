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
    tree = prepareSourceTree {inherit (cfg) source;};
  };

  cargoLock = import ./cargoLock.nix {
    inherit lib;
    inherit (cfg) dreamLock;
    inherit (config.deps) writeText;
  };

  # Backup original Cargo.lock if it exists and write our own one
  writeCargoLock = ''
    echo "dream2nix: replacing Cargo.lock with ${cfg.cargoLock}"
    mv -f Cargo.lock Cargo.lock.orig || echo "dream2nix: no Cargo.lock was found beforehand"
    cat ${cfg.cargoLock} > Cargo.lock
  '';
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.core
  ];

  rust-cargo-lock = {
    inherit
      cargoLock
      dreamLock
      writeCargoLock
      ;
  };

  deps = {nixpkgs, ...}:
    l.mapAttrs (_: l.mkOverride 997) {
      inherit
        (nixpkgs)
        writeText
        ;
    };
}
