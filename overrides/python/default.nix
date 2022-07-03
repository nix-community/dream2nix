{
  lib,
  pkgs,
  # dream2nix
  satisfiesSemver,
  ...
}: let
  l = lib // builtins;

  # include this into an override to enable cntr debugging
  # (linux only)
  cntr = {
    nativeBuildInputs = old: old ++ [pkgs.breakpointHook];
    b = "${pkgs.busybox}/bin/busybox";
  };

  # helper that should be prepended to any sed call to ensure the file
  # is actually modified.
  ensureFileModified = pkgs.writeScript "ensure-file-changed" ''
    #!${pkgs.bash}/bin/bash
    file=$1
    cp $file $TMP/ensureFileModified
    "''${@:2}"
    if diff -q $file $TMP/ensureFileModified; then
      echo -e "file $file could not be modified as expected by command:\n  ''${@:2}"
      exit 1
    fi
  '';

  pythonQtDeps = {
    overrideAttrs = oldAttrs: {
      buildInputs =
        oldAttrs.buildInputs
        ++ (with pkgs; [
          atk.out
          cairo.out
          cups.lib
          gdk-pixbuf.out
          gnome2.pango.out
          gtk3-x11.out
          libsForQt5.full.out
          libsForQt5.qt5.qtgamepad.out
          libsForQt5.qt5.qtspeech.out
          postgresql_14.lib
          speechd.out
          unixODBC.out
        ]);
    };
  };
in
  ## OVERRIDES
  {
    orange3 = {inherit pythonQtDeps;};
    labelimg = {inherit pythonQtDeps;};
    labelme = {inherit pythonQtDeps;};
    urh = {inherit pythonQtDeps;};
  }
