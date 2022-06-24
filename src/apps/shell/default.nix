{
  # dream2nix deps
  utils,
  callNixWithD2N,
  translate,
  ...
}:
utils.writePureShellScriptBin
"shell"
[translate callNixWithD2N]
''
  source="''${1:?"error: pass a source shortcut"}"

  export translateSourceDir="$TMPDIR"
  translate "$source" "packages"

  export dream2nixConfig="{packagesDir=\"packages\"; projectRoot=\"$TMPDIR\";}"

  cd $WORKDIR

  callNixWithD2N shell \
    "(dream2nix.realizeProjects {source = $TMPDIR/src;}).packages"
''
