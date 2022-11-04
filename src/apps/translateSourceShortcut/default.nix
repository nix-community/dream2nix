{pkgs, ...}:
pkgs.writers.writeBash
"translateSourceShortcut"
''
  set -e
  sourceShortcut=''${1:?"error: you must pass a source shortcut"}

  # translate shortcut to source info
  ${pkgs.callNixWithD2N} eval --json \
    "dream2nix.fetchers.translateShortcut {shortcut=\"$sourceShortcut\";}"
''
